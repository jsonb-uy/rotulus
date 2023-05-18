require 'spec_helper'

describe Rotulus::Order do
  subject(:order_definition) do
    described_class.new(
      User,
      {
        last_name: { direction: 'desc', nulls: :last },
        first_name: { direction: :asc },
        'u_l.details' => { direction: :desc, nulls: :first, model: UserLog },
        'u_l.email' => { direction: :asc, model: UserLog }
      }
    )
  end

  describe '#initialize' do
    context 'when a column definition has a :model config' do
      context 'when :model table has a matching column' do
        it 'sets the configured :model to be the column model' do
          order = described_class.new(User, { 'll.details' => { model: UserLog } })

          expect(order.columns.first.model).to eql(UserLog)
        end
      end

      context 'when :model table does not have a matching column' do
        it 'raises an error' do
          expect do
            described_class.new(User, { 'll.xxx' => { model: UserLog } })
          end.to raise_error(Rotulus::InvalidColumnError)
        end
      end
    end

    context 'when a column definition does not have a :model config' do
      context 'when column name has prefix' do
        context 'when the prefix matches the AR relation model table name' do
          context 'when the base AR relation model table has a matching column' do
            it 'sets the AR relation model to be the column model' do
              order = described_class.new(User, { 'users.last_name' => :asc })

              expect(order.columns.first.model).to eql(User)
            end
          end

          context 'when the base AR relation model table does not have a matching column' do
            it 'raises an error' do
              expect do
                described_class.new(User, { 'users.xxx' => :desc })
              end.to raise_error(Rotulus::InvalidColumnError)
            end
          end
        end

        context 'when the prefix does not match the AR relation model table name' do
          it 'raises an error' do
            expect do
              described_class.new(User, { 'userz.first_name' => :desc })
            end.to raise_error(Rotulus::InvalidColumnError)
          end
        end
      end

      context 'when column name does not have a prefix' do
        context 'when the base AR relation model table has a matching column' do
          it 'sets the AR relation model to be the column model' do
            order = described_class.new(User, { 'last_name' => :asc })

            expect(order.columns.first.model).to eql(User)
          end
        end

        context 'when the base AR relation model table does not have a matching column' do
          it 'raises an error' do
            expect do
              described_class.new(User, { 'xxx' => :desc })
            end.to raise_error(Rotulus::InvalidColumnError)
          end
        end
      end
    end
  end

  describe '#columns' do
    it 'returns the ordered column instances' do
      columns = order_definition.columns

      expect(columns[0].name).to eql('last_name')
      expect(columns[0]).to be_desc
      expect(columns[0]).to be_nullable
      expect(columns[0]).to be_nulls_last
      expect(columns[0]).to be_leftmost

      expect(columns[1].name).to eql('first_name')
      expect(columns[1]).to be_asc
      expect(columns[1]).not_to be_nullable
      expect(columns[1]).not_to be_leftmost

      expect(columns[2].name).to eql('u_l.details')
      expect(columns[2]).to be_desc
      expect(columns[2]).to be_nullable
      expect(columns[2]).to be_nulls_first
      expect(columns[2]).not_to be_leftmost

      expect(columns[3].name).to eql('u_l.email')
      expect(columns[3]).to be_asc
      expect(columns[3]).not_to be_distinct
      expect(columns[3]).not_to be_nullable
      expect(columns[3]).not_to be_leftmost
    end

    it 'adds the primary key to the ordered columns as tie-breaker' do
      columns = order_definition.columns
      pk_column = columns.last

      expect(columns.size).to be(5)
      expect(pk_column.name).to eql('id')
      expect(pk_column).to be_asc
      expect(pk_column).to be_distinct
      expect(pk_column).not_to be_nullable
    end

    context 'when the primary key is already included in the order definition' do
      subject(:order_definition) do
        described_class.new(User, { first_name: { direction: :asc },
                                    'users.id' => { direction: :desc },
                                    id: { direction: :asc } })
      end

      it 'does not add the PK to the order definition again' do
        columns = order_definition.columns

        expect(columns.size).to be(2)
        expect(columns[0].name).to eql('first_name')
        expect(columns[1].name).to eql('users.id')
        expect(columns[1]).to be_desc
        expect(columns[1]).to be_distinct
        expect(columns[1]).not_to be_nullable
      end
    end

    context 'when definition is blank' do
      it 'returns the primary key as the only ordered column' do
        column1 = described_class.new(User, nil).columns
        expect(column1.size).to be(1)
        expect(column1.first.name).to eql('id')
        expect(column1.first).to be_asc
        expect(column1.first).to be_distinct
        expect(column1.first).not_to be_nullable

        column2 = described_class.new(User, {}).columns
        expect(column2.size).to be(1)
        expect(column2.first.name).to eql('id')
        expect(column2.first).to be_asc
        expect(column2.first).to be_distinct
        expect(column2.first).not_to be_nullable
      end
    end
  end

  describe '#column_names' do
    it 'returns the ordered column names' do
      names = %w[last_name first_name u_l.details u_l.email id]

      expect(order_definition.column_names).to eql(names)
    end
  end

  describe '#prefixed_column_names' do
    it 'returns the ordered column names with table name prefix' do
      names = %w[users.last_name users.first_name u_l.details u_l.email users.id]

      expect(order_definition.prefixed_column_names).to eql(names)
    end
  end

  describe '#select_sql' do
    it 'returns the SELECT expressions for the ordered columns' do
      sql = <<-SQL
        users.last_name as cursor___users__last_name,
        users.first_name as cursor___users__first_name,
        u_l.details as cursor___u_l__details,
        u_l.email as cursor___u_l__email,
        users.id as cursor___users__id
      SQL

      expect(order_definition.select_sql).to match_sql(sql)
    end
  end

  describe '#selected_values' do
    let(:records) do
      User.where(last_name: 'ABC')
          .joins('LEFT JOIN user_logs u_l ON users.email = u_l.email')
          .select(order_definition.select_sql)
          .order(
            Arel.sql('users.email asc, u_l.details is null, u_l.details asc')
          )
    end

    context 'with record' do
      let!(:user1) { User.find_or_create_by(email: 'b@email.com', first_name: 'B', last_name: 'ABC') }
      let!(:user2) { User.find_or_create_by(email: 'c@email.com', first_name: 'C', last_name: 'ABC') }
      let!(:user_log1) { UserLog.create(email: user1.email, details: 'LOG DETAILS1') }
      let!(:user_log2) { UserLog.create(email: user1.email, details: 'LOG DETAILS2') }

      it 'returns the values of the ordered columns' do
        row1 = records[0]
        row2 = records[1]
        row3 = records[2]

        expect(order_definition.selected_values(row1)).to eql(
          {
            'users.last_name' => 'ABC',
            'users.first_name' => 'B',
            'u_l.details' => 'LOG DETAILS1',
            'u_l.email' => 'b@email.com',
            'users.id' => user1.id
          }
        )

        expect(order_definition.selected_values(row2)).to eql(
          {
            'users.last_name' => 'ABC',
            'users.first_name' => 'B',
            'u_l.details' => 'LOG DETAILS2',
            'u_l.email' => 'b@email.com',
            'users.id' => user1.id
          }
        )

        expect(order_definition.selected_values(row3)).to eql(
          {
            'users.last_name' => 'ABC',
            'users.first_name' => 'C',
            'u_l.details' => nil,
            'u_l.email' => nil,
            'users.id' => user2.id
          }
        )
      end
    end

    context 'with no record' do
      it 'returns an empty hash' do
        expect(order_definition.selected_values(User.none)).to eql({})
        expect(order_definition.selected_values(nil)).to eql({})
      end
    end
  end

  describe '#sql' do
    it 'prefixes the ordered columns with table name to avoid ambiguity' do
      order = described_class.new(User, { 'email' => { direction: :desc },
                                          'users.first_name' => { 'direction' => :asc },
                                          'details' => { model: UserLog } })

      expect(order.sql).to eql('users.email desc,
                                users.first_name asc,
                                user_logs.details asc,
                                users.id asc'.squish)
    end

    context 'when using mysql', :mysql do
      it 'returns the ORDER BY sort expressions' do
        sql = <<-SQL
          users.last_name desc,
          users.first_name asc,
          u_l.details is not null,
          u_l.details desc,
          u_l.email asc,
          users.id asc
        SQL

        expect(order_definition.sql).to match_sql(sql)
      end
    end

    context 'when using postgresql', :postgresql do
      it 'returns the ORDER BY sort expressions' do
        sql = <<-SQL
          users.last_name desc nulls last,
          users.first_name asc,
          u_l.details desc,
          u_l.email asc,
          users.id asc
        SQL

        expect(order_definition.sql).to match_sql(sql)
      end
    end

    context 'when using sqlite', :sqlite do
      it 'returns the ORDER BY sort expressions' do
        sql = <<-SQL
          users.last_name desc,
          users.first_name asc,
          u_l.details desc nulls first,
          u_l.email asc,
          users.id asc
        SQL

        expect(order_definition.sql).to match_sql(sql)
      end
    end
  end

  describe '#reversed_sql' do
    context 'when using mysql', :mysql do
      it 'returns the reversed ORDER BY sort expressions' do
        sql = <<-SQL
          users.last_name asc,
          users.first_name desc,
          u_l.details is null,
          u_l.details asc,
          u_l.email desc,
          users.id desc
        SQL

        expect(order_definition.reversed_sql).to match_sql(sql)
      end
    end

    context 'when using postgresql', :postgresql do
      it 'returns the reversed ORDER BY sort expressions' do
        sql = <<-SQL
          users.last_name asc nulls first,
          users.first_name desc,
          u_l.details asc,
          u_l.email desc,
          users.id desc
        SQL

        expect(order_definition.reversed_sql).to match_sql(sql)
      end
    end

    context 'when using sqlite', :sqlite do
      it 'returns the reversed ORDER BY sort expressions' do
        sql = <<-SQL
          users.last_name asc,
          users.first_name desc,
          u_l.details asc nulls last,
          u_l.email desc,
          users.id desc
        SQL

        expect(order_definition.reversed_sql).to match_sql(sql)
      end
    end
  end

  describe '#state' do
    it "returns a string representing the order definition's state" do
      expect(order_definition.state).to be_a(String)

      order_definition_copy = described_class.new(
        User,
        {
          last_name: { direction: :desc, nulls: 'LAST' },
          'users.first_name' => { direction: :asc, nulls: 'last' },
          'u_l.details' => { direction: 'DESC', nulls: 'first', model: UserLog },
          'u_l.email' => { direction: 'ASC', model: UserLog }
        }
      )

      expect(order_definition.state).to eql(order_definition_copy.state)
    end

    context 'when the ordered column sort direction changed' do
      subject(:order_definition) do
        described_class.new(User, { last_name: { direction: :asc } })
      end

      it 'returns a new state' do
        order_definition_copy = described_class.new(
          User,
          {
            last_name: { direction: :desc }
          }
        )

        expect(order_definition.state).not_to eql(order_definition_copy.state)
      end
    end

    context 'when the ordered column :nulls option changed' do
      subject(:order_definition) do
        described_class.new(User, { last_name: { direction: :asc, nulls: :first } })
      end

      it 'returns a new state' do
        order_definition_copy = described_class.new(
          User,
          {
            last_name: { direction: :asc, nulls: 'last' }
          }
        )

        expect(order_definition.state).not_to eql(order_definition_copy.state)
      end
    end

    context 'when the ordered column :distinct option changed' do
      subject(:order_definition) do
        described_class.new(User, { last_name: { direction: :asc, distinct: true } })
      end

      it 'returns a new state' do
        order_definition_copy = described_class.new(
          User,
          {
            last_name: { direction: :asc }
          }
        )

        expect(order_definition.state).not_to eql(order_definition_copy.state)
      end
    end

    context 'when the ordered column\'s nullability changed' do
      subject(:order_definition) do
        described_class.new(User, { last_name: { direction: :asc } })
      end

      it 'returns a new state' do
        orig_state = order_definition.state

        column = order_definition.columns.first
        allow(column).to receive_messages(nullable?: false)

        expect(order_definition.state).not_to eql(orig_state)
      end
    end
  end

  describe '#to_h' do
    it 'returns a hash representation of the ordered columns' do
      expect(order_definition.to_h).to eql(
        {
          'users.last_name' => {
            direction: :desc,
            nulls: :last,
            nullable: true,
            distinct: false
          },
          'users.first_name' => {
            direction: :asc,
            nullable: false,
            distinct: false
          },
          'u_l.details' => {
            direction: :desc,
            nulls: :first,
            nullable: true,
            distinct: false
          },
          'u_l.email' => {
            direction: :asc,
            nullable: false,
            distinct: false
          },
          'users.id' => {
            direction: :asc,
            nullable: false,
            distinct: true
          }
        }
      )
    end
  end

  it 'supports order definition to be in compact form' do
    order_definition = described_class.new(User, { last_name: :asc, first_name: :desc })

    columns = order_definition.columns

    expect(columns[0].name).to eql('last_name')
    expect(columns[0]).to be_asc
    expect(columns[0]).to be_nullable
    expect(columns[0]).to be_leftmost

    expect(columns[1].name).to eql('first_name')
    expect(columns[1]).to be_desc
    expect(columns[1]).not_to be_nullable
    expect(columns[1]).not_to be_leftmost

    expect(columns[2].name).to eql('id')
    expect(columns[2]).to be_asc
    expect(columns[2]).to be_distinct
    expect(columns[2]).not_to be_nullable
    expect(columns[2]).not_to be_leftmost
  end
end
