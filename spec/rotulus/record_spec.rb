require 'spec_helper'

describe Rotulus::Record do
  subject(:record) { new_record(page_order: order) }
  let(:order) { nil }

  def new_record(values: nil, page_order: {})
    page = Rotulus::Page.new(User.all, order: page_order)
    default_values = {
      'users.last_name' => 'Drake',
      'users.first_name' => 'Nick',
      'users.middle_name' => 'Rodney',
      'users.mobile' => '6399999999',
      'users.email' => 'ndrake@email.com',
      'users.ssn' => '918-123-6412',
      'users.created_at' => '2023-01-01T01:01:02.003123Z'.to_time,
      'users.id' => 11
    }

    described_class.new(page, values.presence || default_values)
  end

  describe '#sql_seek_condition' do
    context 'when page has no order definition' do
      it 'returns the SQL condition that filters by the PK' do
        expect(record.sql_seek_condition(:prev)).to eql('users.id < 11')
        expect(record.sql_seek_condition(:next)).to eql('users.id > 11')
      end
    end

    context 'with `asc` non-nullable + distinct column' do
      let(:order) { { email: { direction: :asc, distinct: true } } }

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + distinct column' do
      let(:order) { { email: { direction: :desc, distinct: true } } }

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `asc` non-nullable + non-distinct column' do
      let(:order) { { first_name: { direction: :asc } } }

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.first_name <= 'Nick' AND (
            users.first_name < 'Nick' OR (
              users.first_name = 'Nick' AND users.id < 11
            )
          )
        SQL

        next_sql = <<-SQL
          users.first_name >= 'Nick' AND (
            users.first_name > 'Nick' OR (
              users.first_name = 'Nick' AND users.id > 11
            )
          )
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + non-distinct column' do
      let(:order) { { first_name: { direction: :desc } } }

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.first_name >= 'Nick' AND (
            users.first_name > 'Nick' OR (
              users.first_name = 'Nick' AND users.id < 11
            )
          )
        SQL

        next_sql = <<-SQL
          users.first_name <= 'Nick' AND (
            users.first_name < 'Nick' OR (
              users.first_name = 'Nick' AND users.id > 11
            )
          )
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `asc nulls first` nullable + distinct column' do
      let(:order) { { ssn: { direction: :asc, nulls: :first, distinct: true } } }

      context 'with nil column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND users.id < 11
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (
              users.ssn IS NULL AND users.id > 11
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column' do
      let(:order) { { ssn: { direction: :asc, nulls: :last, distinct: true } } }
      context 'with nil column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (
              users.ssn IS NULL AND users.id < 11
            )
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND users.id > 11
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column' do
      let(:order) { { ssn: { direction: :desc, nulls: :first, distinct: true } } }

      context 'with nil column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND users.id < 11
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (
              users.ssn IS NULL AND users.id > 11
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column' do
      let(:order) { { ssn: { direction: :desc, nulls: :last, distinct: true } } }

      context 'with nil column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (
              users.ssn IS NULL AND users.id < 11
            )
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND users.id > 11
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + non-distinct column' do
      let(:order) { { last_name: { direction: :asc, nulls: :first } } }

      context 'with nil column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND users.id < 11
          SQL

          next_sql = <<-SQL
              users.last_name IS NOT NULL OR (
                users.last_name IS NULL AND users.id > 11
              )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND (
              (users.last_name < 'Drake' OR users.last_name IS NULL) OR (
                users.last_name = 'Drake' AND users.id < 11
              )
            )
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (
              users.last_name > 'Drake' OR (
                users.last_name = 'Drake' AND users.id > 11
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column' do
      let(:order) { { last_name: { direction: :asc, nulls: :last } } }

      context 'with nil column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (
              users.last_name IS NULL AND users.id < 11
            )
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND users.id > 11
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (
              users.last_name < 'Drake' OR (
                users.last_name = 'Drake' AND users.id < 11
              )
            )
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND (
              (users.last_name > 'Drake' OR users.last_name IS NULL) OR (
                users.last_name = 'Drake' AND users.id > 11
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column' do
      let(:order) { { last_name: { direction: :desc, nulls: :first } } }
      context 'with nil column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND users.id < 11
          SQL

          next_sql = <<-SQL
              users.last_name IS NOT NULL OR (
                users.last_name IS NULL AND users.id > 11
              )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND (
              (users.last_name > 'Drake' OR users.last_name IS NULL) OR (
                users.last_name = 'Drake' AND users.id < 11
              )
            )
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (
              users.last_name < 'Drake' OR (
                users.last_name = 'Drake' AND users.id > 11
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column' do
      let(:order) { { last_name: { direction: :desc, nulls: :last } } }

      context 'with nil column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (
              users.last_name IS NULL AND users.id < 11
            )
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND users.id > 11
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (
              users.last_name > 'Drake' OR (
                users.last_name = 'Drake' AND users.id < 11
              )
            )
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND (
              (users.last_name < 'Drake' OR users.last_name IS NULL) OR (
                users.last_name = 'Drake' AND users.id > 11
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    ## nonnullable-distinct + nonnullable-distinct combo
    context 'with `asc` non-nullable + distinct column and `asc` non-nullable + distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :asc, distinct: true },
            first_name: { direction: :asc, distinct: true }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `asc` non-nullable + distinct column and `desc` non-nullable + distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :asc, distinct: true },
            first_name: { direction: :desc, distinct: true }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + distinct column and `asc` non-nullable + distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :desc, distinct: true },
            first_name: { direction: :asc, distinct: true }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + distinct column and `desc` non-nullable + distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :desc, distinct: true },
            first_name: { direction: :desc, distinct: true }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    ## nonnullable-distinct + nonnullable-nondistinct combo
    context 'with `asc` non-nullable + distinct column and `asc` non-nullable + non-distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :asc, distinct: true },
            first_name: { direction: :asc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `asc` non-nullable + distinct column and `desc` non-nullable + non-distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :asc, distinct: true },
            first_name: { direction: :desc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + distinct column and `asc` non-nullable + non-distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :desc, distinct: true },
            first_name: { direction: :asc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + distinct column and `desc` non-nullable + non-distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :desc, distinct: true },
            first_name: { direction: :desc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    ## nonnullable-distinct + nullable-distinct combo
    context 'with `asc` non-nullable + distinct column and `asc` nullable + distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :asc, distinct: true },
            ssn: { direction: :asc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `asc` non-nullable + distinct column and `desc` nullable + distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :asc, distinct: true },
            ssn: { direction: :desc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + distinct column and `asc` nullable + distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :desc, distinct: true },
            ssn: { direction: :asc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + distinct column and `desc` nullable + distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :desc, distinct: true },
            ssn: { direction: :desc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    ## nonnullable-distinct + nullable-nondistinct combo
    context 'with `asc` non-nullable + distinct column and `asc` nullable + non-distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :asc, distinct: true },
            last_name: { direction: :asc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `asc` non-nullable + distinct column and `desc` nullable + non-distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :asc, distinct: true },
            last_name: { direction: :desc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + distinct column and `asc` nullable + non-distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :desc, distinct: true },
            last_name: { direction: :asc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + distinct column and `desc` nullable + non-distinct columns' do
      subject(:record) do
        new_record(
          page_order: {
            email: { direction: :desc, distinct: true },
            last_name: { direction: :desc }
          }
        )
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.email > 'ndrake@email.com'
        SQL

        next_sql = <<-SQL
          users.email < 'ndrake@email.com'
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    ## nonnullable-nondistinct + nonnullable-distinct combo
    context 'with `asc` non-nullable + non-distinct column and `asc` non-nullable + distinct columns' do
      subject(:record) do
        new_record(page_order: { first_name: { direction: :asc },
                                 email: { direction: :asc, distinct: true } })
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.first_name <= 'Nick' AND (
            users.first_name < 'Nick' OR (
              users.first_name = 'Nick' AND (users.email < 'ndrake@email.com')
            )
          )
        SQL

        next_sql = <<-SQL
          users.first_name >= 'Nick' AND (
            users.first_name > 'Nick' OR (
              users.first_name = 'Nick' AND (users.email > 'ndrake@email.com')
            )
          )
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `asc` non-nullable + non-distinct column and `desc` non-nullable + distinct columns' do
      subject(:record) do
        new_record(page_order: { first_name: { direction: :asc },
                                 email: { direction: :desc, distinct: true } })
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.first_name <= 'Nick' AND (
            users.first_name < 'Nick' OR (
              users.first_name = 'Nick' AND (users.email > 'ndrake@email.com')
            )
          )
        SQL

        next_sql = <<-SQL
          users.first_name >= 'Nick' AND (
            users.first_name > 'Nick' OR (
              users.first_name = 'Nick' AND (users.email < 'ndrake@email.com')
            )
          )
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `asc` non-nullable + distinct columns' do
      subject(:record) do
        new_record(page_order: { first_name: { direction: :desc },
                                 email: { direction: :asc, distinct: true } })
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.first_name >= 'Nick' AND (
            users.first_name > 'Nick' OR (
              users.first_name = 'Nick' AND (users.email < 'ndrake@email.com')
            )
          )
        SQL

        next_sql = <<-SQL
          users.first_name <= 'Nick' AND (
            users.first_name < 'Nick' OR (
              users.first_name = 'Nick' AND (users.email > 'ndrake@email.com')
            )
          )
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `desc` non-nullable + distinct columns' do
      subject(:record) do
        new_record(page_order: { first_name: { direction: :desc },
                                 email: { direction: :desc, distinct: true } })
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.first_name >= 'Nick' AND (
            users.first_name > 'Nick' OR (
              users.first_name = 'Nick' AND (users.email > 'ndrake@email.com')
            )
          )
        SQL

        next_sql = <<-SQL
          users.first_name <= 'Nick' AND (
            users.first_name < 'Nick' OR (
              users.first_name = 'Nick' AND (users.email < 'ndrake@email.com')
            )
          )
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    ## nonnullable-nondistinct + nonnullable-nondistinct combo
    context 'with `asc` non-nullable + non-distinct column and `asc` non-nullable + non-distinct columns' do
      subject(:record) do
        new_record(page_order: { first_name: { direction: :asc }, created_at: { direction: :asc } })
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.first_name <= 'Nick' AND (
            users.first_name < 'Nick' OR (
              users.first_name = 'Nick' AND (
                users.created_at < '2023-01-01T01:01:02.003123Z' OR (
                  users.created_at = '2023-01-01T01:01:02.003123Z' AND users.id < 11
                )
              )
            )
          )
        SQL

        next_sql = <<-SQL
          users.first_name >= 'Nick' AND (
            users.first_name > 'Nick' OR (
              users.first_name = 'Nick' AND (
                users.created_at > '2023-01-01T01:01:02.003123Z' OR (
                  users.created_at = '2023-01-01T01:01:02.003123Z' AND users.id > 11
                )
              )
            )
          )
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `asc` non-nullable + non-distinct column and `desc` non-nullable + non-distinct columns' do
      subject(:record) do
        new_record(page_order: { first_name: { direction: :asc }, created_at: { direction: :desc } })
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.first_name <= 'Nick' AND (
            users.first_name < 'Nick' OR (
              users.first_name = 'Nick' AND (
                users.created_at > '2023-01-01T01:01:02.003123Z' OR (
                  users.created_at = '2023-01-01T01:01:02.003123Z' AND users.id < 11
                )
              )
            )
          )
        SQL

        next_sql = <<-SQL
          users.first_name >= 'Nick' AND (
            users.first_name > 'Nick' OR (
              users.first_name = 'Nick' AND (
                users.created_at < '2023-01-01T01:01:02.003123Z' OR (
                  users.created_at = '2023-01-01T01:01:02.003123Z' AND users.id > 11
                )
              )
            )
          )
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `asc` non-nullable + non-distinct columns' do
      subject(:record) do
        new_record(page_order: { first_name: { direction: :desc }, created_at: { direction: :asc } })
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.first_name >= 'Nick' AND (
            users.first_name > 'Nick' OR (
              users.first_name = 'Nick' AND (
                users.created_at < '2023-01-01T01:01:02.003123Z' OR (
                  users.created_at = '2023-01-01T01:01:02.003123Z' AND users.id < 11
                )
              )
            )
          )
        SQL

        next_sql = <<-SQL
          users.first_name <= 'Nick' AND (
            users.first_name < 'Nick' OR (
              users.first_name = 'Nick' AND (
                users.created_at > '2023-01-01T01:01:02.003123Z' OR (
                  users.created_at = '2023-01-01T01:01:02.003123Z' AND users.id > 11
                )
              )
            )
          )
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `desc` non-nullable + non-distinct columns' do
      subject(:record) do
        new_record(page_order: { first_name: { direction: :desc }, created_at: { direction: :desc } })
      end

      it 'returns the correct SQL condition' do
        prev_sql = <<-SQL
          users.first_name >= 'Nick' AND (
            users.first_name > 'Nick' OR (
              users.first_name = 'Nick' AND (
                users.created_at > '2023-01-01T01:01:02.003123Z' OR (
                  users.created_at = '2023-01-01T01:01:02.003123Z' AND users.id < 11
                )
              )
            )
          )
        SQL

        next_sql = <<-SQL
          users.first_name <= 'Nick' AND (
            users.first_name < 'Nick' OR (
              users.first_name = 'Nick' AND (
                users.created_at < '2023-01-01T01:01:02.003123Z' OR (
                  users.created_at = '2023-01-01T01:01:02.003123Z' AND users.id > 11
                )
              )
            )
          )
        SQL

        expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
        expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
      end
    end

    ## nonnullable-nondistinct + nullable-distinct combo
    context 'with `asc` non-nullable + non-distinct column and `asc nulls first` nullable + distinct columns' do
      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :asc },
                                   ssn: { direction: :asc, nulls: :first, distinct: true } },
                     values: { 'users.first_name' => 'Nick', 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NULL AND users.id < 11
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NOT NULL OR (
                    users.ssn IS NULL AND users.id > 11
                  )
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :asc },
                                   ssn: { direction: :asc, nulls: :first, distinct: true } },
                     values: { 'users.first_name' => 'Nick',
                               'users.ssn' => '918-123-6412',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn < '918-123-6412' OR users.ssn IS NULL)
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR
              (users.first_name = 'Nick' AND (users.ssn > '918-123-6412'))
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc` non-nullable + non-distinct column and `asc nulls last` nullable + distinct columns' do
      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :asc },
                                   ssn: { direction: :asc, nulls: :last, distinct: true } },
                     values: { 'users.first_name' => 'Nick', 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NOT NULL OR
                  (users.ssn IS NULL AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn IS NULL AND users.id > 11)
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :asc },
                                   ssn: { direction: :asc, nulls: :last, distinct: true } },
                     values: { 'users.first_name' => 'Nick',
                               'users.ssn' => '918-123-6412',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn < '918-123-6412')
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn > '918-123-6412' OR users.ssn IS NULL)
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc` non-nullable + non-distinct column and `desc nulls first` nullable + distinct columns' do
      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :asc },
                                   ssn: { direction: :desc, nulls: :first, distinct: true } },
                     values: { 'users.first_name' => 'Nick', 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NULL AND users.id < 11
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NOT NULL OR (
                    users.ssn IS NULL AND users.id > 11
                  )
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :asc },
                                   ssn: { direction: :desc, nulls: :first, distinct: true } },
                     values: { 'users.first_name' => 'Nick',
                               'users.ssn' => '918-123-6412',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn > '918-123-6412' OR users.ssn IS NULL)
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn < '918-123-6412')
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc` non-nullable + non-distinct column and `desc nulls last` nullable + distinct columns' do
      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :asc },
                                   ssn: { direction: :desc, nulls: :last, distinct: true } },
                     values: { 'users.first_name' => 'Nick', 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NOT NULL OR
                  (users.ssn IS NULL AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn IS NULL AND users.id > 11)
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :asc },
                                   ssn: { direction: :desc, nulls: :last, distinct: true } },
                     values: { 'users.first_name' => 'Nick',
                               'users.ssn' => '918-123-6412',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn > '918-123-6412')
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn < '918-123-6412' OR users.ssn IS NULL)
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `asc nulls first` nullable + distinct columns' do
      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :desc },
                                   ssn: { direction: :asc, nulls: :first, distinct: true } },
                     values: { 'users.first_name' => 'Nick', 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NULL AND users.id < 11
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NOT NULL OR (
                    users.ssn IS NULL AND users.id > 11
                  )
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :desc },
                                   ssn: { direction: :asc, nulls: :first, distinct: true } },
                     values: { 'users.first_name' => 'Nick',
                               'users.ssn' => '918-123-6412',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn < '918-123-6412' OR users.ssn IS NULL)
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn > '918-123-6412')
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `asc nulls last` nullable + distinct columns' do
      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :desc },
                                   ssn: { direction: :asc, nulls: :last, distinct: true } },
                     values: { 'users.first_name' => 'Nick', 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NOT NULL OR
                  (users.ssn IS NULL AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn IS NULL AND users.id > 11)
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :desc },
                                   ssn: { direction: :asc, nulls: :first, distinct: true } },
                     values: { 'users.first_name' => 'Nick',
                               'users.ssn' => '918-123-6412',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn < '918-123-6412' OR users.ssn IS NULL)
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn > '918-123-6412')
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `desc nulls first` nullable + distinct columns' do
      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :desc },
                                   ssn: { direction: :desc, nulls: :first, distinct: true } },
                     values: { 'users.first_name' => 'Nick', 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NULL AND users.id < 11
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NOT NULL OR (
                    users.ssn IS NULL AND users.id > 11
                  )
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :desc },
                                   ssn: { direction: :desc, nulls: :first, distinct: true } },
                     values: { 'users.first_name' => 'Nick',
                               'users.ssn' => '918-123-6412',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn > '918-123-6412' OR users.ssn IS NULL)
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn < '918-123-6412')
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `desc nulls last` nullable + distinct columns' do
      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :desc },
                                   ssn: { direction: :desc, nulls: :last, distinct: true } },
                     values: { 'users.first_name' => 'Nick', 'users.ssn' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.ssn IS NOT NULL OR
                  (users.ssn IS NULL AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn IS NULL AND users.id > 11)
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: { first_name: { direction: :desc },
                                   ssn: { direction: :desc, nulls: :last, distinct: true } },
                     values: { 'users.first_name' => 'Nick',
                               'users.ssn' => '918-123-6412',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.ssn > '918-123-6412')
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND 
                (users.ssn < '918-123-6412' OR users.ssn IS NULL)
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    ## nonnullable-nondistinct + nullable-nondistinct combo
    context 'with `asc` non-nullable + non-distinct column and `asc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { first_name: { direction: :asc },
          last_name: { direction: :asc, nulls: :first } }
      end

      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick', 'last_name.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NULL AND users.id < 11
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NOT NULL OR (
                    users.last_name IS NULL AND users.id > 11
                  )
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick',
                               'users.last_name' => 'Drake',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  (users.last_name < 'Drake' OR users.last_name IS NULL) OR
                  (users.last_name = 'Drake' AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name > 'Drake' OR
                  (users.last_name = 'Drake' AND users.id > 11)
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc` non-nullable + non-distinct column and `asc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { first_name: { direction: :asc }, last_name: { direction: :asc, nulls: :last } }
      end

      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NOT NULL OR
                  (users.last_name IS NULL AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.last_name IS NULL AND users.id > 11)
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick',
                               'users.last_name' => 'Drake',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name < 'Drake' OR
                  (users.last_name = 'Drake' AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  (users.last_name > 'Drake' OR users.last_name IS NULL) OR
                  (users.last_name = 'Drake' AND users.id > 11)
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc` non-nullable + non-distinct column and `desc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { first_name: { direction: :asc }, last_name: { direction: :desc, nulls: :first } }
      end

      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NULL AND users.id < 11
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NOT NULL OR (
                    users.last_name IS NULL AND users.id > 11
                  )
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick',
                               'users.last_name' => 'Drake',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  (users.last_name > 'Drake' OR users.last_name IS NULL) OR
                  (users.last_name = 'Drake' AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name < 'Drake' OR
                  (users.last_name = 'Drake' AND users.id > 11)
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc` non-nullable + non-distinct column and `desc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { first_name: { direction: :asc },
          last_name: { direction: :desc, nulls: :last } }
      end

      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NOT NULL OR
                  (users.last_name IS NULL AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.last_name IS NULL AND users.id > 11)
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick',
                               'users.last_name' => 'Drake',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name > 'Drake' OR
                  (users.last_name = 'Drake' AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  (users.last_name < 'Drake' OR users.last_name IS NULL) OR
                  (users.last_name = 'Drake' AND users.id > 11)
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `asc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { first_name: { direction: :desc },
          last_name: { direction: :asc, nulls: :first } }
      end

      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NULL AND users.id < 11
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NOT NULL OR (
                    users.last_name IS NULL AND users.id > 11
                  )
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick',
                               'users.last_name' => 'Drake',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  (users.last_name < 'Drake' OR users.last_name IS NULL) OR
                  (users.last_name = 'Drake' AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name > 'Drake' OR
                  (users.last_name = 'Drake' AND users.id > 11)
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `asc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { first_name: { direction: :desc },
          last_name: { direction: :asc, nulls: :last } }
      end

      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NOT NULL OR
                  (users.last_name IS NULL AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.last_name IS NULL AND users.id > 11)
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick',
                               'users.last_name' => 'Drake',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name < 'Drake' OR
                  (users.last_name = 'Drake' AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  (users.last_name > 'Drake' OR users.last_name IS NULL) OR
                  (users.last_name = 'Drake' AND users.id > 11)
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `desc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { first_name: { direction: :desc },
          last_name: { direction: :desc, nulls: :first } }
      end

      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NULL AND users.id < 11
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NOT NULL OR (
                    users.last_name IS NULL AND users.id > 11
                  )
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick',
                               'users.last_name' => 'Drake',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  (users.last_name > 'Drake' OR users.last_name IS NULL) OR
                  (users.last_name = 'Drake' AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name < 'Drake' OR
                  (users.last_name = 'Drake' AND users.id > 11)
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc` non-nullable + non-distinct column and `desc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { first_name: { direction: :desc }, last_name: { direction: :desc, nulls: :last } }
      end

      context 'with nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name IS NOT NULL OR
                  (users.last_name IS NULL AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND
                (users.last_name IS NULL AND users.id > 11)
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.first_name' => 'Nick',
                               'users.last_name' => 'Drake',
                               'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.first_name >= 'Nick' AND (
              users.first_name > 'Nick' OR (
                users.first_name = 'Nick' AND (
                  users.last_name > 'Drake' OR
                  (users.last_name = 'Drake' AND users.id < 11)
                )
              )
            )
          SQL

          next_sql = <<-SQL
            users.first_name <= 'Nick' AND (
              users.first_name < 'Nick' OR (
                users.first_name = 'Nick' AND (
                  (users.last_name < 'Drake' OR users.last_name IS NULL) OR
                  (users.last_name = 'Drake' AND users.id > 11)
                )
              )
            )
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    ## nullable-distinct + nonnullable-distinct combo
    context 'with `asc nulls first` nullable + distinct column and `asc` non-nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true },
          email: { direction: :asc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.email < 'ndrake@email.com')
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.email > 'ndrake@email.com'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '811-021-243' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '811-021-243'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `asc` non-nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true },
          email: { direction: :asc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.email < 'ndrake@email.com'))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.email > 'ndrake@email.com')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '811-021-243'
          SQL

          next_sql = <<-SQL
            users.ssn > '811-021-243' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + distinct column and `desc` non-nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true },
         email: { direction: :desc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.email > 'ndrake@email.com')
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.email < 'ndrake@email.com'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '811-021-243' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '811-021-243'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `desc` non-nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true },
          email: { direction: :desc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.email > 'ndrake@email.com'))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.email < 'ndrake@email.com')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '811-021-243'
          SQL

          next_sql = <<-SQL
            users.ssn > '811-021-243' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `asc` non-nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true },
         email: { direction: :asc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.email < 'ndrake@email.com')
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.email > 'ndrake@email.com'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '811-021-243' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '811-021-243'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `asc` non-nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true },
         email: { direction: :asc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.email < 'ndrake@email.com'))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.email > 'ndrake@email.com')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '811-021-243'
          SQL

          next_sql = <<-SQL
            users.ssn < '811-021-243' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `desc` non-nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true },
         email: { direction: :desc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.email > 'ndrake@email.com')
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.email < 'ndrake@email.com'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '811-021-243' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '811-021-243'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `desc` non-nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true },
         email: { direction: :desc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.email > 'ndrake@email.com'))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.email < 'ndrake@email.com')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '811-021-243'
          SQL

          next_sql = <<-SQL
            users.ssn < '811-021-243' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    ## nullable-distinct + nonnullable-nondistinct combo
    context 'with `asc nulls first` nullable + distinct column and `asc` non-nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true }, first_name: { direction: :asc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id > 11)
            ))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '811-021-243' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '811-021-243'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `asc` non-nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true }, first_name: { direction: :asc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id < 11)
            ))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '811-021-243'
          SQL

          next_sql = <<-SQL
            users.ssn > '811-021-243' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + distinct column and `desc` non-nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true }, first_name: { direction: :desc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id > 11)
            ))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '811-021-243' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '811-021-243'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `desc` non-nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true }, first_name: { direction: :desc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id < 11)
            ))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '811-021-243'
          SQL

          next_sql = <<-SQL
            users.ssn > '811-021-243' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `asc` non-nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true }, first_name: { direction: :asc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id > 11)
            ))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '811-021-243' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '811-021-243'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `asc` non-nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true }, first_name: { direction: :asc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id < 11)
            ))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '811-021-243'
          SQL

          next_sql = <<-SQL
            users.ssn < '811-021-243' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `desc` non-nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true }, first_name: { direction: :desc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id > 11)
            ))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '811-021-243' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '811-021-243'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `desc` non-nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true }, first_name: { direction: :desc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id < 11)
            ))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '811-021-243', 'users.email' => 'ndrake@email.com', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '811-021-243'
          SQL

          next_sql = <<-SQL
            users.ssn < '811-021-243' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    ## nullable-distinct + nullable-distinct combo
    context 'with `asc nulls first` nullable + distinct column and `asc nulls first` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true },
          mobile: { direction: :asc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile > '6399999999'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + distinct column and `asc nulls last` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true },
          mobile: { direction: :asc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile < '6399999999')
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.mobile > '6399999999' OR users.mobile IS NULL))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + distinct column and `desc nulls first` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true },
          mobile: { direction: :desc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile > '6399999999' OR users.mobile IS NULL)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile < '6399999999'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + distinct column and `desc nulls last` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true },
          mobile: { direction: :desc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile > '6399999999')
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `asc nulls first` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true },
          mobile: { direction: :asc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile > '6399999999')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `asc nulls last` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true },
          mobile: { direction: :asc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11)
            ))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile < '6399999999'))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile > '6399999999' OR users.mobile IS NULL)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `desc nulls first` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true },
          mobile: { direction: :desc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile > '6399999999' OR users.mobile IS NULL))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile < '6399999999')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `desc nulls last` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true },
          mobile: { direction: :desc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))) 
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile > '6399999999'))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `asc nulls first` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true },
          mobile: { direction: :asc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile > '6399999999'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `asc nulls last` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true },
          mobile: { direction: :asc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile < '6399999999')
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.mobile > '6399999999' OR users.mobile IS NULL))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `desc nulls first` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true },
          mobile: { direction: :desc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile > '6399999999' OR users.mobile IS NULL)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile < '6399999999'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `desc nulls last` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true },
          mobile: { direction: :desc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile > '6399999999')
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `asc nulls first` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true },
          mobile: { direction: :asc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile > '6399999999')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `asc nulls last` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true },
          mobile: { direction: :asc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11)
            ))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile < '6399999999'))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile > '6399999999' OR users.mobile IS NULL)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `desc nulls first` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true },
          mobile: { direction: :desc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile > '6399999999' OR users.mobile IS NULL))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile < '6399999999')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `desc nulls last` nullable + distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true },
          mobile: { direction: :desc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))) 
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.mobile > '6399999999'))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    ## nullable-distinct + nullable-nondistinct combo
    context 'with `asc nulls first` nullable + distinct column and `asc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true }, last_name: { direction: :asc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND ((users.last_name < 'Drake' OR users.last_name IS NULL)
            OR (users.last_name = 'Drake' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name > 'Drake'
              OR (users.last_name = 'Drake' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + distinct column and `asc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true }, last_name: { direction: :asc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name < 'Drake' OR (users.last_name = 'Drake' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + distinct column and `desc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true }, last_name: { direction: :desc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND ((users.last_name > 'Drake' OR users.last_name IS NULL)
              OR (users.last_name = 'Drake' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + distinct column and `desc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :first, distinct: true }, last_name: { direction: :desc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name > 'Drake' OR (users.last_name = 'Drake' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              (users.last_name < 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `asc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true }, last_name: { direction: :asc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              (users.last_name < 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name > 'Drake' OR (users.last_name = 'Drake' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `asc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true }, last_name: { direction: :asc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id < 11)
            ))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `desc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true }, last_name: { direction: :desc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              (users.last_name > 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name < 'Drake' OR (users.last_name = 'Drake' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + distinct column and `desc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :asc, nulls: :last, distinct: true }, last_name: { direction: :desc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id < 11))) 
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `asc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true }, last_name: { direction: :asc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `asc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true }, last_name: { direction: :asc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name < 'Drake' OR (users.last_name = 'Drake' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
               (users.last_name > 'Drake' OR users.last_name IS NULL) OR
               (users.last_name = 'Drake' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `desc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true }, last_name: { direction: :desc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + distinct column and `desc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :first, distinct: true }, last_name: { direction: :desc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name > 'Drake' OR (users.last_name = 'Drake' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              (users.last_name < 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412'
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `asc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true }, last_name: { direction: :asc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              (users.last_name < 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name > 'Drake' OR (users.last_name = 'Drake' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `asc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true }, last_name: { direction: :asc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (
              users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id < 11)
            ))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `desc nulls first` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true }, last_name: { direction: :desc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name < 'Drake' OR (users.last_name = 'Drake' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + distinct column and `desc nulls last` nullable + non-distinct columns' do
      let(:order) do
        { ssn: { direction: :desc, nulls: :last, distinct: true }, last_name: { direction: :desc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND
              (users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id < 11))) 
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND (users.last_name IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => nil, 'users.last_name' => 'Drake', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL AND ((users.last_name < 'Drake' OR users.last_name IS NULL)
              OR (users.last_name = 'Drake' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.ssn' => '918-123-6412', 'users.last_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.ssn > '918-123-6412'
          SQL

          next_sql = <<-SQL
            users.ssn < '918-123-6412' OR users.ssn IS NULL
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    ## nullable-nondistinct + nonnullable-distinct combo
    context 'with `asc nulls first` nullable + non-distinct column and `asc` non-nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first }, email: { direction: :asc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.email < 'ndrake@email.com')
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.email > 'ndrake@email.com'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => 'Drake', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.email < 'ndrake@email.com')))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.email > 'ndrake@email.com')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + non-distinct column and `desc` non-nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first }, email: { direction: :desc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.email > 'ndrake@email.com')
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.email < 'ndrake@email.com'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => 'Drake', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.email > 'ndrake@email.com')))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.email < 'ndrake@email.com')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `asc` non-nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, email: { direction: :asc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.email < 'ndrake@email.com'))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.email > 'ndrake@email.com')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => 'Drake', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.email < 'ndrake@email.com')))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.email > 'ndrake@email.com')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `desc` non-nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, email: { direction: :desc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.email > 'ndrake@email.com'))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.email < 'ndrake@email.com')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => 'Drake', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.email > 'ndrake@email.com')))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.email < 'ndrake@email.com')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `asc` non-nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, email: { direction: :asc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.email < 'ndrake@email.com')
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.email > 'ndrake@email.com'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => 'Drake', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.email < 'ndrake@email.com')))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.email > 'ndrake@email.com')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `desc` non-nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, email: { direction: :desc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.email > 'ndrake@email.com')
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.email < 'ndrake@email.com'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => 'Drake', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.email > 'ndrake@email.com')))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.email < 'ndrake@email.com')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `asc` non-nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, email: { direction: :asc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.email < 'ndrake@email.com'))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.email > 'ndrake@email.com')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => 'Drake', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.email < 'ndrake@email.com')))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.email > 'ndrake@email.com')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `desc` non-nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, email: { direction: :desc, distinct: true } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => nil, 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.email > 'ndrake@email.com'))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.email < 'ndrake@email.com')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order, values: { 'users.last_name' => 'Drake', 'users.email' => 'ndrake@email.com' })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.email > 'ndrake@email.com')))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.email < 'ndrake@email.com')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    ## nullable-nondistinct + nonnullable-nondistinct combo
    context 'with `asc nulls first` nullable + non-distinct column and `asc` non-nullable + non-distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first }, first_name: { direction: :asc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                    values: { 'users.last_name' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.first_name < 'Nick' OR 
              (users.first_name = 'Nick' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.first_name < 'Nick' OR
                  (users.first_name = 'Nick' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.first_name > 'Nick' OR
              (users.first_name = 'Nick' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + non-distinct column and `desc` non-nullable + non-distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first }, first_name: { direction: :desc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND
              (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND (users.first_name > 'Nick' OR
              (users.first_name = 'Nick' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.first_name < 'Nick' OR
              (users.first_name = 'Nick' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `asc` non-nullable + non-distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, first_name: { direction: :asc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.first_name < 'Nick' OR
              (users.first_name = 'Nick' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND (users.first_name > 'Nick' OR
              (users.first_name = 'Nick' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `desc` non-nullable + non-distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, first_name: { direction: :desc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.first_name < 'Nick' OR
              (users.first_name = 'Nick' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.first_name > 'Nick' OR
              (users.first_name = 'Nick' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND (users.first_name < 'Nick' OR
              (users.first_name = 'Nick' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `asc` non-nullable + non-distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, first_name: { direction: :asc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.first_name < 'Nick' OR
              (users.first_name = 'Nick' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.first_name < 'Nick' OR
                  (users.first_name = 'Nick' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.first_name > 'Nick' OR
              (users.first_name = 'Nick' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `desc` non-nullable + non-distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, first_name: { direction: :desc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND
              (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND (users.first_name > 'Nick' OR
              (users.first_name = 'Nick' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.first_name < 'Nick' OR
              (users.first_name = 'Nick' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `asc` non-nullable + non-distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, first_name: { direction: :asc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.first_name < 'Nick' OR (users.first_name = 'Nick' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.first_name < 'Nick' OR
              (users.first_name = 'Nick' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND (users.first_name > 'Nick' OR
              (users.first_name = 'Nick' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `desc` non-nullable + non-distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, first_name: { direction: :desc } }
      end

      context 'with nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.first_name > 'Nick' OR (users.first_name = 'Nick' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.first_name < 'Nick' OR
              (users.first_name = 'Nick' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.first_name' => 'Nick', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.first_name > 'Nick' OR
              (users.first_name = 'Nick' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND (users.first_name < 'Nick' OR
              (users.first_name = 'Nick' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    ## nullable-nondistinct + nullable-distinct combo
    context 'with `asc nulls first` nullable + non-distinct column and `asc nulls first` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first }, mobile: { direction: :asc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile > '6399999999'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR
              (users.mobile IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
              (users.last_name = 'Drake' AND (users.mobile < '6399999999' OR users.mobile IS NULL)))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile > '6399999999')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + non-distinct column and `asc nulls last` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first }, mobile: { direction: :asc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile < '6399999999')
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.mobile > '6399999999' OR users.mobile IS NULL))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR
                  (users.mobile IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile < '6399999999')))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile > '6399999999' OR users.mobile IS NULL)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + non-distinct column and `desc nulls first` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first }, mobile: { direction: :desc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile > '6399999999' OR users.mobile IS NULL)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile < '6399999999'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR
                (users.mobile IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile > '6399999999' OR users.mobile IS NULL)))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile < '6399999999')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + non-distinct column and `desc nulls last` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first },
          mobile: { direction: :desc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile > '6399999999')
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR
                  (users.mobile IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile > '6399999999')))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile < '6399999999' OR users.mobile IS NULL)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `asc nulls first` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, mobile: { direction: :asc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile > '6399999999')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR (users.last_name = 'Drake' AND
              (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR
                  (users.mobile IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR (users.last_name = 'Drake' AND
              (users.mobile < '6399999999' OR users.mobile IS NULL)))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile > '6399999999')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `asc nulls last` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, mobile: { direction: :asc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile < '6399999999'))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile > '6399999999' OR users.mobile IS NULL)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR (users.last_name = 'Drake' AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile < '6399999999')))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile > '6399999999' OR users.mobile IS NULL)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `desc nulls first` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, mobile: { direction: :desc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile > '6399999999' OR users.mobile IS NULL))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile < '6399999999')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR (users.last_name = 'Drake'
              AND (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile > '6399999999' OR users.mobile IS NULL)))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile < '6399999999')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `desc nulls last` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, mobile: { direction: :desc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile > '6399999999'))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR (users.last_name = 'Drake' AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile > '6399999999')))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile < '6399999999' OR users.mobile IS NULL)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `asc nulls first` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, mobile: { direction: :asc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile > '6399999999'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR
                (users.mobile IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile < '6399999999' OR users.mobile IS NULL)))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile > '6399999999')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `asc nulls last` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, mobile: { direction: :asc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile < '6399999999')
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.mobile > '6399999999' OR users.mobile IS NULL))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile < '6399999999')))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile > '6399999999' OR users.mobile IS NULL)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `desc nulls first` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, mobile: { direction: :desc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile > '6399999999' OR users.mobile IS NULL)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile < '6399999999'))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile > '6399999999' OR users.mobile IS NULL)))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile < '6399999999')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `desc nulls last` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, mobile: { direction: :desc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile > '6399999999')
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR (users.last_name = 'Drake' AND
                (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile > '6399999999')))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile < '6399999999' OR users.mobile IS NULL)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `asc nulls first` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, mobile: { direction: :asc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile > '6399999999')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR (users.last_name = 'Drake' AND
                (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile < '6399999999' OR users.mobile IS NULL)))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile > '6399999999')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `asc nulls last` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, mobile: { direction: :asc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile < '6399999999'))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile > '6399999999' OR users.mobile IS NULL)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile < '6399999999')))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile > '6399999999' OR users.mobile IS NULL)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `desc nulls first` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, mobile: { direction: :desc, nulls: :first, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.mobile > '6399999999' OR users.mobile IS NULL))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile < '6399999999')
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile > '6399999999' OR users.mobile IS NULL)))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile < '6399999999')))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `desc nulls last` nullable + distinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, mobile: { direction: :desc, nulls: :last, distinct: true } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.mobile' => '6399999999', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.mobile > '6399999999'))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.mobile < '6399999999' OR users.mobile IS NULL)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.mobile' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile IS NOT NULL OR (users.mobile IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.mobile > '6399999999')))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.mobile < '6399999999' OR users.mobile IS NULL)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    ## nullable-nondistinct + nullable-nondistinct combo
    context 'with `asc nulls first` nullable + non-distinct column and `asc nulls first` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first }, middle_name: { direction: :asc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND ((users.middle_name < 'Rodney' OR users.middle_name IS NULL)
              OR (users.middle_name = 'Rodney' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name > 'Rodney' OR (users.middle_name = 'Rodney' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR
              (users.middle_name IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND ((users.middle_name < 'Rodney' OR
                  users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name > 'Rodney' OR
                (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + non-distinct column and `asc nulls last` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first }, middle_name: { direction: :asc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.middle_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name < 'Rodney' OR
              (users.middle_name = 'Rodney' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              ((users.middle_name > 'Rodney' OR users.middle_name IS NULL) OR
                (users.middle_name = 'Rodney' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR
                  (users.middle_name IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name < 'Rodney' OR
                  (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND ((users.middle_name > 'Rodney' OR
                users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + non-distinct column and `desc nulls first` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first }, middle_name: { direction: :desc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND ((users.middle_name > 'Rodney' OR users.middle_name IS NULL) OR
              (users.middle_name = 'Rodney' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name < 'Rodney' OR (users.middle_name = 'Rodney' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR
                (users.middle_name IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND ((users.middle_name > 'Rodney' OR
                  users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR (users.last_name = 'Drake' AND
              (users.middle_name < 'Rodney' OR (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls first` nullable + non-distinct column and `desc nulls last` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :first },
          middle_name: { direction: :desc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.middle_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name > 'Rodney' OR (users.middle_name = 'Rodney' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND ((users.middle_name < 'Rodney' OR
              users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR
                  (users.middle_name IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name > 'Rodney' OR
                  (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND ((users.middle_name < 'Rodney' OR
                users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `asc nulls first` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, middle_name: { direction: :asc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.middle_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              ((users.middle_name < 'Rodney' OR users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name > 'Rodney' OR (users.middle_name = 'Rodney' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR (users.last_name = 'Drake' AND
              (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR
                  (users.middle_name IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND ((users.middle_name < 'Rodney' OR
                users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name > 'Rodney' OR
                  (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `asc nulls last` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, middle_name: { direction: :asc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name < 'Rodney' OR (users.middle_name = 'Rodney' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND ((users.middle_name > 'Rodney' OR
              users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR
                (users.middle_name IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name < 'Rodney' OR
                (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND ((users.middle_name > 'Rodney' OR
                  users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `desc nulls first` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, middle_name: { direction: :desc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.middle_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              ((users.middle_name > 'Rodney' OR users.middle_name IS NULL) OR
                (users.middle_name = 'Rodney' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name < 'Rodney' OR
              (users.middle_name = 'Rodney' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR (users.last_name = 'Drake'
              AND (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR
                  (users.middle_name IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND ((users.middle_name > 'Rodney' OR
                users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name < 'Rodney' OR
                  (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `asc nulls last` nullable + non-distinct column and `desc nulls last` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :asc, nulls: :last }, middle_name: { direction: :desc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name > 'Rodney' OR (users.middle_name = 'Rodney' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND ((users.middle_name < 'Rodney' OR users.middle_name IS NULL) OR
              (users.middle_name = 'Rodney' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR (users.last_name = 'Drake' AND
              (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name > 'Rodney' OR
                (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND ((users.middle_name < 'Rodney' OR
                  users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `asc nulls first` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, middle_name: { direction: :asc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND ((users.middle_name < 'Rodney' OR users.middle_name IS NULL) OR
              (users.middle_name = 'Rodney' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.middle_name > 'Rodney'
              OR (users.middle_name = 'Rodney' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR
                (users.middle_name IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND ((users.middle_name < 'Rodney' OR
                  users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name > 'Rodney' OR
                (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `asc nulls last` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, middle_name: { direction: :asc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.middle_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name < 'Rodney' OR
              (users.middle_name = 'Rodney' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              ((users.middle_name > 'Rodney' OR users.middle_name IS NULL) OR
                (users.middle_name = 'Rodney' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name < 'Rodney' OR
                  (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND ((users.middle_name > 'Rodney' OR
                users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `desc nulls first` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, middle_name: { direction: :desc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NULL AND users.id < 11)
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND ((users.middle_name > 'Rodney' OR
              users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name < 'Rodney' OR (users.middle_name = 'Rodney' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND ((users.middle_name > 'Rodney' OR
                  users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name < 'Rodney' OR
                (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls first` nullable + non-distinct column and `desc nulls last` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :first }, middle_name: { direction: :desc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.middle_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name > 'Rodney' OR
              (users.middle_name = 'Rodney' AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              ((users.middle_name < 'Rodney' OR users.middle_name IS NULL) OR
                (users.middle_name = 'Rodney' AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR (users.last_name = 'Drake' AND
                (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            (users.last_name >= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name > 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name > 'Rodney' OR
                  (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            users.last_name <= 'Drake' AND (users.last_name < 'Drake' OR
              (users.last_name = 'Drake' AND ((users.middle_name < 'Rodney' OR
                users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `asc nulls first` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, middle_name: { direction: :asc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.middle_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              ((users.middle_name < 'Rodney' OR users.middle_name IS NULL) OR
                (users.middle_name = 'Rodney' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name > 'Rodney' OR
              (users.middle_name = 'Rodney' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR (users.last_name = 'Drake' AND
                (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND ((users.middle_name < 'Rodney' OR
                users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name > 'Rodney' OR
                  (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `asc nulls last` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, middle_name: { direction: :asc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name < 'Rodney' OR (users.middle_name = 'Rodney' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND ((users.middle_name > 'Rodney' OR
              users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name < 'Rodney' OR
                (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND ((users.middle_name > 'Rodney' OR
                  users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `desc nulls first` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, middle_name: { direction: :desc, nulls: :first } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND (users.middle_name IS NULL AND users.id < 11))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              ((users.middle_name > 'Rodney' OR users.middle_name IS NULL) OR
                (users.middle_name = 'Rodney' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name < 'Rodney' OR
              (users.middle_name = 'Rodney' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND ((users.middle_name > 'Rodney' OR
                users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name < 'Rodney' OR
                  (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end

    context 'with `desc nulls last` nullable + non-distinct column and `desc nulls last` nullable + nondistinct columns' do
      let(:order) do
        { last_name: { direction: :desc, nulls: :last }, middle_name: { direction: :desc, nulls: :last } }
      end

      context 'with nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND (users.middle_name IS NULL AND users.id > 11)
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with nil 1st column value and non-nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => nil, 'users.middle_name' => 'Rodney', 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL AND
              (users.middle_name > 'Rodney' OR (users.middle_name = 'Rodney' AND users.id < 11)))
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL AND ((users.middle_name < 'Rodney' OR
              users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and nil 2nd column value' do
        subject(:record) do
          new_record(page_order: order,
                     values: { 'users.last_name' => 'Drake', 'users.middle_name' => nil, 'users.id' => 11 })
        end

        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name IS NOT NULL OR (users.middle_name IS NULL AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND (users.middle_name IS NULL AND users.id > 11)))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end

      context 'with non-nil 1st column value and non-nil 2nd column value' do
        it 'returns the correct SQL condition' do
          prev_sql = <<-SQL
            users.last_name >= 'Drake' AND (users.last_name > 'Drake' OR
              (users.last_name = 'Drake' AND (users.middle_name > 'Rodney' OR
                (users.middle_name = 'Rodney' AND users.id < 11))))
          SQL

          next_sql = <<-SQL
            (users.last_name <= 'Drake' OR users.last_name IS NULL) AND
              ((users.last_name < 'Drake' OR users.last_name IS NULL) OR
                (users.last_name = 'Drake' AND ((users.middle_name < 'Rodney' OR
                  users.middle_name IS NULL) OR (users.middle_name = 'Rodney' AND users.id > 11))))
          SQL

          expect(record.sql_seek_condition(:prev)).to match_sql(prev_sql)
          expect(record.sql_seek_condition(:next)).to match_sql(next_sql)
        end
      end
    end
  end

  describe '#state' do
    it 'returns a string representing the state based on the values' do
      expect(record.state).to be_a(String)

      record_copy = new_record(values: record.values, page_order: order)
      expect(record.state).to eql(record_copy.state)
    end

    context 'when the record changed' do
      it 'returns a new state' do
        record_copy = new_record(values: { some_value: 1 }, page_order: order)

        expect(record.state).not_to eql(record_copy.state)
      end
    end
  end
end
