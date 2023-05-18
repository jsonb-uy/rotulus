require 'spec_helper'

describe Rotulus::Column do
  subject(:column) { described_class.new(User, :last_name) }

  describe '.select_alias_to_name' do
    it 'returns the column name given a SELECT alias' do
      expect(described_class.select_alias_to_name('cursor___users__last_name')).to eql('users.last_name')
      expect(described_class.select_alias_to_name('cursor___x_table__y_z')).to eql('x_table.y_z')
      expect(described_class.select_alias_to_name('cursor___last_name')).to eql('last_name')
    end
  end

  describe '.select_alias' do
    it 'returns the SELECT alias given a column name' do
      expect(described_class.select_alias('users.last_name')).to eql('cursor___users__last_name')
      expect(described_class.select_alias('x_table.y_z')).to eql('cursor___x_table__y_z')
      expect(described_class.select_alias(:last_name)).to eql('cursor___last_name')
    end
  end

  describe '#initialize' do
    context 'with :name' do
      subject(:column) { described_class.new(User, :first_name) }

      it 'converts it to string for convenience' do
        expect(column.name).to eql('first_name')
      end
    end

    context 'with nil or blank :name value' do
      it 'raises an error' do
        expect { described_class.new(User, ' ') }.to raise_error(Rotulus::InvalidColumnError)
        expect { described_class.new(User, nil) }.to raise_error(Rotulus::InvalidColumnError)
      end
    end

    context 'with :name in invalid format' do
      it 'raises an error' do
        expect { described_class.new(User, '1abc') }.to raise_error(Rotulus::InvalidColumnError)
        expect { described_class.new(User, 'abc.1def') }.to raise_error(Rotulus::InvalidColumnError)
        expect { described_class.new(User, "' OR 1=1") }.to raise_error(Rotulus::InvalidColumnError)
        expect { described_class.new(User, "abc\'") }.to raise_error(Rotulus::InvalidColumnError)
      end
    end
  end

  describe '#direction' do
    context 'with `asc` :direction ' do
      it 'returns :asc' do
        col1 = described_class.new(User, :email, direction: 'asc')
        col2 = described_class.new(User, :email, direction: 'ASC')
        col3 = described_class.new(User, :email, direction: :asc)

        expect(col1.direction).to be(:asc)
        expect(col2.direction).to be(:asc)
        expect(col3.direction).to be(:asc)
      end
    end

    context 'with `desc` :direction' do
      it 'returns :desc' do
        col1 = described_class.new(User, :email, direction: 'desc')
        col2 = described_class.new(User, :email, direction: 'DESC')
        col3 = described_class.new(User, :email, direction: :desc)

        expect(col1.direction).to be(:desc)
        expect(col2.direction).to be(:desc)
        expect(col3.direction).to be(:desc)
      end
    end

    context 'with nil :direction value' do
      it 'returns :asc' do
        col1 = described_class.new(User, :email)
        col2 = described_class.new(User, :email, direction: nil)

        expect(col1.direction).to be(:asc)
        expect(col2.direction).to be(:asc)
      end
    end

    context 'with unrecognized :direction' do
      it 'returns :asc' do
        col1 = described_class.new(User, :email, direction: 'asending')
        col2 = described_class.new(User, :email, direction: 'descending')

        expect(col1.direction).to be(:asc)
        expect(col2.direction).to be(:asc)
      end
    end
  end

  describe '#distinct?' do
    context 'with `true` :distinct value' do
      it 'returns true' do
        col1 = described_class.new(User, :last_name, distinct: true)
        col2 = described_class.new(User, 'users.last_name', distinct: true)
        col3 = described_class.new(User, 'some_table.xyz', distinct: true)
        col4 = described_class.new(User, 'users2.id', distinct: true)

        expect(col1).to be_distinct
        expect(col2).to be_distinct
        expect(col3).to be_distinct
        expect(col4).to be_distinct
      end
    end

    context 'with `false` :distinct value' do
      context 'when column is the primary key of :model table' do
        it 'returns false' do
          col1 = described_class.new(User, :id, distinct: false)
          col2 = described_class.new(User, 'users.id', distinct: false)

          expect(col1).not_to be_distinct
          expect(col2).not_to be_distinct
        end
      end

      context 'when column is not the primary key of :model table' do
        it 'returns false' do
          col1 = described_class.new(User, :last_name, distinct: false)
          col2 = described_class.new(User, 'users.last_name', distinct: false)

          expect(col1).not_to be_distinct
          expect(col2).not_to be_distinct
        end
      end
    end

    context 'with nil :distinct value' do
      context 'when column is the primary key of :model table' do
        it 'returns true' do
          col1 = described_class.new(User, :id)
          col2 = described_class.new(User, 'users.id', distinct: nil)

          expect(col1).to be_distinct
          expect(col2).to be_distinct
        end
      end

      context 'when column is not the primary key of :model table' do
        it 'returns false' do
          col1 = described_class.new(User, :last_name)
          col2 = described_class.new(User, 'users.last_name', distinct: nil)

          expect(col1).not_to be_distinct
          expect(col2).not_to be_distinct
        end
      end
    end
  end

  describe '#nullable?' do
    context 'with nil :nullable value' do
      context 'when column is the primary key of its table' do
        it 'returns false' do
          expect(described_class.new(User, :id)).not_to be_nullable
          expect(described_class.new(User, 'id')).not_to be_nullable
          expect(described_class.new(User, 'users.id')).not_to be_nullable
        end
      end

      context 'when column is nullable in its table' do
        it 'returns true' do
          expect(described_class.new(User, :last_name)).to be_nullable
          expect(described_class.new(User, 'users.last_name')).to be_nullable
        end
      end

      context 'when column is not nullable in its table' do
        it 'returns false' do
          expect(described_class.new(User, :email)).not_to be_nullable
          expect(described_class.new(User, 'users.email')).not_to be_nullable

          expect(described_class.new(User, :first_name)).not_to be_nullable
          expect(described_class.new(User, 'users.first_name')).not_to be_nullable
        end
      end
    end

    context 'with `false` :nullable value' do
      context 'when column is the primary key of its table' do
        it 'returns false' do
          expect(described_class.new(User, :id, nullable: false)).not_to be_nullable
          expect(described_class.new(User, 'id', nullable: false)).not_to be_nullable
          expect(described_class.new(User, 'users.id', nullable: false)).not_to be_nullable
        end
      end

      context 'when column is nullable in its table' do
        it 'returns false' do
          expect(described_class.new(User, :last_name, nullable: false)).not_to be_nullable
          expect(described_class.new(User, 'users.last_name', nullable: false)).not_to be_nullable
        end
      end

      context 'when column is not nullable in its table' do
        it 'returns false' do
          expect(described_class.new(User, :email, nullable: false)).not_to be_nullable
          expect(described_class.new(User, 'users.email', nullable: false)).not_to be_nullable

          expect(described_class.new(User, :first_name, nullable: false)).not_to be_nullable
          expect(described_class.new(User, 'users.first_name', nullable: false)).not_to be_nullable
        end
      end
    end

    context 'with `true` :nullable value' do
      context 'when column is the primary key of its table' do
        it 'returns true' do
          expect(described_class.new(User, :id, nullable: true)).to be_nullable
          expect(described_class.new(User, 'id', nullable: true)).to be_nullable
          expect(described_class.new(User, 'users.id', nullable: true)).to be_nullable
        end
      end

      context 'when column is nullable in its table' do
        it 'returns true' do
          expect(described_class.new(User, :last_name, nullable: true)).to be_nullable
          expect(described_class.new(User, 'users.last_name', nullable: true)).to be_nullable
        end
      end

      context 'when column is not nullable in its table' do
        it 'returns true' do
          expect(described_class.new(User, :email, nullable: true)).to be_nullable
          expect(described_class.new(User, 'users.email', nullable: true)).to be_nullable

          expect(described_class.new(User, :first_name, nullable: true)).to be_nullable
          expect(described_class.new(User, 'users.first_name', nullable: true)).to be_nullable
        end
      end
    end
  end

  describe '#nulls' do
    context 'when column is nullable' do
      context 'with `first` :nulls value' do
        it 'returns :first' do
          col1 = described_class.new(User, :last_name, nulls: :first)
          col2 = described_class.new(User, :last_name, nulls: 'first')
          col3 = described_class.new(User, :last_name, nulls: 'FIRST')

          expect(col1.nulls).to be(:first)
          expect(col2.nulls).to be(:first)
          expect(col3.nulls).to be(:first)
        end
      end

      context 'with `last` :nulls value' do
        it 'returns :last' do
          col1 = described_class.new(User, :last_name, nulls: :last)
          col2 = described_class.new(User, :last_name, nulls: 'last')
          col3 = described_class.new(User, :last_name, nulls: 'LAST')

          expect(col1.nulls).to be(:last)
          expect(col2.nulls).to be(:last)
          expect(col3.nulls).to be(:last)
        end
      end

      context 'with nil :nulls value' do
        context 'with `asc` :direction' do
          let(:col1) { described_class.new(User, :last_name, direction: :asc, nulls: nil) }
          let(:col2) { described_class.new(User, :last_name, direction: :asc) }

          context 'with postgresql database', :postgresql do
            it 'returns :last' do
              expect(col1.nulls).to be(:last)
              expect(col2.nulls).to be(:last)
            end
          end

          context 'with sqlite database', :sqlite do
            it 'returns :first' do
              expect(col1.nulls).to be(:first)
              expect(col2.nulls).to be(:first)
            end
          end
        end

        context 'with `desc` :direction' do
          let(:col1) { described_class.new(User, :last_name, direction: :desc, nulls: nil) }
          let(:col2) { described_class.new(User, :last_name, direction: :desc) }

          context 'with postgresql database', :postgresql do
            it 'returns :first' do
              expect(col1.nulls).to be(:first)
              expect(col2.nulls).to be(:first)
            end
          end

          context 'with sqlite database', :sqlite do
            it 'returns :last' do
              expect(col1.nulls).to be(:last)
              expect(col2.nulls).to be(:last)
            end
          end
        end
      end

      context 'with unrecognized :nulls option value' do
        context 'with `asc` :direction' do
          context 'with postgresql database', :postgresql do
            it 'returns :last' do
              col1 = described_class.new(User, :last_name, direction: :asc, nulls: 'foo')

              expect(col1.nulls).to be(:last)
            end
          end

          context 'with sqlite database', :sqlite do
            it 'returns :first' do
              col1 = described_class.new(User, :last_name, direction: :asc, nulls: 'foo')

              expect(col1.nulls).to be(:first)
            end
          end
        end

        context 'with `desc` :direction' do
          context 'with postgresql database', :postgresql do
            it 'returns :first' do
              col1 = described_class.new(User, :last_name, direction: :desc, nulls: 'bar')

              expect(col1.nulls).to be(:first)
            end
          end

          context 'with sqlite database', :sqlite do
            it 'returns :last' do
              col1 = described_class.new(User, :last_name, direction: :desc, nulls: 'bar')

              expect(col1.nulls).to be(:last)
            end
          end
        end
      end
    end

    context 'when column is not nullable' do
      it 'returns nil' do
        expect(described_class.new(User, :last_name, nulls: :first, nullable: false).nulls).to be_nil
        expect(described_class.new(User, :email, nulls: :first).nulls).to be_nil
        expect(described_class.new(User, :id, nulls: :last).nulls).to be_nil
        expect(described_class.new(User, :id).nulls).to be_nil
      end
    end
  end

  describe '#nulls_first?' do
    context 'when column is nullable' do
      context 'with `first` :nulls value' do
        it 'returns true' do
          col1 = described_class.new(User, :last_name, nulls: :first)
          col2 = described_class.new(User, :last_name, nulls: 'first')
          col3 = described_class.new(User, :last_name, nulls: 'FIRST')

          expect(col1).to be_nulls_first
          expect(col2).to be_nulls_first
          expect(col3).to be_nulls_first
        end
      end

      context 'with `last` :nulls value' do
        it 'returns false' do
          col1 = described_class.new(User, :last_name, nulls: :last)
          col2 = described_class.new(User, :last_name, nulls: 'last')
          col3 = described_class.new(User, :last_name, nulls: 'LAST')

          expect(col1).not_to be_nulls_first
          expect(col2).not_to be_nulls_first
          expect(col3).not_to be_nulls_first
        end
      end

      context 'with nil :nulls value' do
        context 'with postgresql database', :postgresql do
          context 'with `asc` :direction' do
            it 'returns false' do
              col1 = described_class.new(User, :last_name, direction: :asc, nulls: nil)
              col2 = described_class.new(User, :last_name, direction: :asc)

              expect(col1).not_to be_nulls_first
              expect(col2).not_to be_nulls_first
            end
          end

          context 'with `desc` :direction' do
            it 'returns true' do
              col1 = described_class.new(User, :last_name, direction: :desc, nulls: nil)
              col2 = described_class.new(User, :last_name, direction: :desc)

              expect(col1).to be_nulls_first
              expect(col2).to be_nulls_first
            end
          end
        end

        context 'with sqlite database', :sqlite do
          context 'with `asc` :direction' do
            it 'returns true' do
              col1 = described_class.new(User, :last_name, direction: :asc, nulls: nil)
              col2 = described_class.new(User, :last_name, direction: :asc)

              expect(col1).to be_nulls_first
              expect(col2).to be_nulls_first
            end
          end

          context 'with `desc` :direction' do
            it 'returns false' do
              col1 = described_class.new(User, :last_name, direction: :desc, nulls: nil)
              col2 = described_class.new(User, :last_name, direction: :desc)

              expect(col1).not_to be_nulls_first
              expect(col2).not_to be_nulls_first
            end
          end
        end
      end

      context 'with unrecognized :nulls option value' do
        context 'with postgresql database', :postgresql do
          context 'with `asc` :direction' do
            it 'returns false' do
              col1 = described_class.new(User, :last_name, direction: :asc, nulls: 'foo')

              expect(col1).not_to be_nulls_first
            end
          end

          context 'with `desc` :direction' do
            it 'returns true' do
              col1 = described_class.new(User, :last_name, direction: :desc, nulls: 'bar')

              expect(col1).to be_nulls_first
            end
          end
        end

        context 'with sqlite database', :sqlite do
          context 'with `asc` :direction' do
            it 'returns true' do
              col1 = described_class.new(User, :last_name, direction: :asc, nulls: 'foo')

              expect(col1).to be_nulls_first
            end
          end

          context 'with `desc` :direction' do
            it 'returns false' do
              col1 = described_class.new(User, :last_name, direction: :desc, nulls: 'bar')

              expect(col1).not_to be_nulls_first
            end
          end
        end
      end
    end

    context 'when column is not nullable' do
      it 'returns false' do
        expect(described_class.new(User, :email, nulls: :first)).not_to be_nulls_first
        expect(described_class.new(User, :id, nulls: :last)).not_to be_nulls_first
        expect(described_class.new(User, :id)).not_to be_nulls_first
      end
    end
  end

  describe '#nulls_last?' do
    context 'when column is nullable' do
      context 'with `first` :nulls value' do
        it 'returns false' do
          col1 = described_class.new(User, :last_name, nulls: :first)
          col2 = described_class.new(User, :last_name, nulls: 'first')
          col3 = described_class.new(User, :last_name, nulls: 'FIRST')

          expect(col1).not_to be_nulls_last
          expect(col2).not_to be_nulls_last
          expect(col3).not_to be_nulls_last
        end
      end

      context 'with `last` :nulls value' do
        it 'returns true' do
          col1 = described_class.new(User, :last_name, nulls: :last)
          col2 = described_class.new(User, :last_name, nulls: 'last')
          col3 = described_class.new(User, :last_name, nulls: 'LAST')

          expect(col1).to be_nulls_last
          expect(col2).to be_nulls_last
          expect(col3).to be_nulls_last
        end
      end

      context 'with nil :nulls value' do
        context 'with postgresql database', :postgresql do
          context 'with `asc` :direction' do
            it 'returns true' do
              col1 = described_class.new(User, :last_name, direction: :asc, nulls: nil)
              col2 = described_class.new(User, :last_name, direction: :asc)

              expect(col1).to be_nulls_last
              expect(col2).to be_nulls_last
            end
          end

          context 'with `desc` :direction' do
            it 'returns false' do
              col1 = described_class.new(User, :last_name, direction: :desc, nulls: nil)
              col2 = described_class.new(User, :last_name, direction: :desc)

              expect(col1).not_to be_nulls_last
              expect(col2).not_to be_nulls_last
            end
          end
        end

        context 'with sqlite database', :sqlite do
          context 'with `asc` :direction' do
            it 'returns false' do
              col1 = described_class.new(User, :last_name, direction: :asc, nulls: nil)
              col2 = described_class.new(User, :last_name, direction: :asc)

              expect(col1).not_to be_nulls_last
              expect(col2).not_to be_nulls_last
            end
          end

          context 'with `desc` :direction' do
            it 'returns true' do
              col1 = described_class.new(User, :last_name, direction: :desc, nulls: nil)
              col2 = described_class.new(User, :last_name, direction: :desc)

              expect(col1).to be_nulls_last
              expect(col2).to be_nulls_last
            end
          end
        end
      end

      context 'with unrecognized :nulls option value' do
        context 'with postgresql database', :postgresql do
          context 'with `asc` :direction' do
            it 'returns true' do
              col1 = described_class.new(User, :last_name, direction: :asc, nulls: 'foo')

              expect(col1).to be_nulls_last
            end
          end

          context 'with `desc` :direction' do
            it 'returns false' do
              col1 = described_class.new(User, :last_name, direction: :desc, nulls: 'bar')

              expect(col1).not_to be_nulls_last
            end
          end
        end

        context 'with sqlite database', :sqlite do
          context 'with `asc` :direction' do
            it 'returns true' do
              col1 = described_class.new(User, :last_name, direction: :asc, nulls: 'foo')

              expect(col1).not_to be_nulls_last
            end
          end

          context 'with `desc` :direction' do
            it 'returns false' do
              col1 = described_class.new(User, :last_name, direction: :desc, nulls: 'bar')

              expect(col1).to be_nulls_last
            end
          end
        end
      end
    end

    context 'when column is not nullable' do
      it 'returns false' do
        expect(described_class.new(User, :email, nulls: :first)).not_to be_nulls_last
        expect(described_class.new(User, :id, nulls: :last)).not_to be_nulls_last
        expect(described_class.new(User, :id)).not_to be_nulls_last
      end
    end
  end

  describe '#as_leftmost!' do
    it 'marks the column as the highest-priority(leftmost in ORDER BY exp) in the ordered columns' do
      col1 = column

      expect(column.as_leftmost!).to be(column)
      expect(col1).to be_leftmost
    end
  end

  describe '#leftmost?' do
    context 'when column is the highest-priority(leftmost in ORDER BY exp) in the ordered columns' do
      it 'returns true' do
        expect(column).not_to be_leftmost

        column.as_leftmost!

        expect(column).to be_leftmost
      end
    end

    context 'when column is not marked as the highest-priority in the ordered columns' do
      it 'returns false' do
        expect(column).not_to be_leftmost
      end
    end
  end

  describe '#asc?' do
    context 'with `asc` :direction ' do
      it 'returns true' do
        col1 = described_class.new(User, :email, direction: 'asc')
        col2 = described_class.new(User, :email, direction: 'ASC')
        col3 = described_class.new(User, :email, direction: :asc)

        expect(col1).to be_asc
        expect(col2).to be_asc
        expect(col3).to be_asc
      end
    end

    context 'with `desc` :direction' do
      it 'returns false' do
        col1 = described_class.new(User, :email, direction: 'desc')
        col2 = described_class.new(User, :email, direction: 'DESC')
        col3 = described_class.new(User, :email, direction: :desc)

        expect(col1).not_to be_asc
        expect(col2).not_to be_asc
        expect(col3).not_to be_asc
      end
    end

    context 'with nil :direction value' do
      it 'returns true' do
        col1 = described_class.new(User, :email)
        col2 = described_class.new(User, :email, direction: nil)

        expect(col1).to be_asc
        expect(col2).to be_asc
      end
    end

    context 'with unrecognized :direction' do
      it 'returns true' do
        col1 = described_class.new(User, :email, direction: 'asending')
        col2 = described_class.new(User, :email, direction: 'descending')

        expect(col1).to be_asc
        expect(col2).to be_asc
      end
    end
  end

  describe '#desc?' do
    context 'with `asc` :direction ' do
      it 'returns false' do
        col1 = described_class.new(User, :email, direction: 'asc')
        col2 = described_class.new(User, :email, direction: 'ASC')
        col3 = described_class.new(User, :email, direction: :asc)

        expect(col1).not_to be_desc
        expect(col2).not_to be_desc
        expect(col3).not_to be_desc
      end
    end

    context 'with `desc` :direction' do
      it 'returns true' do
        col1 = described_class.new(User, :email, direction: 'desc')
        col2 = described_class.new(User, :email, direction: 'DESC')
        col3 = described_class.new(User, :email, direction: :desc)

        expect(col1).to be_desc
        expect(col2).to be_desc
        expect(col3).to be_desc
      end
    end

    context 'with nil :direction value' do
      it 'returns false' do
        col1 = described_class.new(User, :email)
        col2 = described_class.new(User, :email, direction: nil)

        expect(col1).not_to be_desc
        expect(col2).not_to be_desc
      end
    end

    context 'with unrecognized :direction' do
      it 'returns false' do
        col1 = described_class.new(User, :email, direction: 'asending')
        col2 = described_class.new(User, :email, direction: 'descending')

        expect(col1).not_to be_desc
        expect(col2).not_to be_desc
      end
    end
  end

  describe '#unprefixed_name' do
    it 'returns the column name without the table/alias prefix' do
      col1 = described_class.new(User, :last_name)
      col2 = described_class.new(User, 'users.last_name')
      col3 = described_class.new(User, 'some_table.xyz')

      expect(col1.unprefixed_name).to eql('last_name')
      expect(col2.unprefixed_name).to eql('last_name')
      expect(col3.unprefixed_name).to eql('xyz')
    end
  end

  describe '#prefixed_name' do
    context 'when column name does not have a prefix' do
      it 'returns the column name prepended with the table name' do
        expect(column.prefixed_name).to eql('users.last_name')
      end
    end

    context 'when column name already has prefix' do
      it 'returns the column name as-is' do
        col1 = described_class.new(User, 'users.last_name')
        col2 = described_class.new(User, 'some_table.xyz')

        expect(col1.prefixed_name).to eql('users.last_name')
        expect(col2.prefixed_name).to eql('some_table.xyz')
      end
    end
  end

  describe '#select_alias' do
    it 'returns the SELECT alias given a column name' do
      col1 = described_class.new(User, :last_name)
      col2 = described_class.new(User, 'users.last_name')
      col3 = described_class.new(User, 'some_table.xyz')

      expect(col1.select_alias).to eql('cursor___users__last_name')
      expect(col2.select_alias).to eql('cursor___users__last_name')
      expect(col3.select_alias).to eql('cursor___some_table__xyz')
    end
  end

  describe '#to_h' do
    it 'returns a hash representation of the column' do
      col1 = described_class.new(User, :first_name, direction: :asc)
      col2 = described_class.new(User, 'users.last_name', direction: :desc, nulls: :last)
      col3 = described_class.new(User, :email, direction: :asc, distinct: true)
      col4 = described_class.new(User, :id, direction: :desc)

      expect(col1.to_h).to eql(
        {
          'users.first_name' => {
            direction: :asc,
            nullable: false,
            distinct: false
          }
        }
      )

      expect(col2.to_h).to eql(
        {
          'users.last_name' => {
            direction: :desc,
            nulls: :last,
            nullable: true,
            distinct: false
          }
        }
      )

      expect(col3.to_h).to eql(
        {
          'users.email' => {
            direction: :asc,
            nullable: false,
            distinct: true
          }
        }
      )

      expect(col4.to_h).to eql(
        {
          'users.id' => {
            direction: :desc,
            nullable: false,
            distinct: true
          }
        }
      )
    end
  end

  describe '#order_sql' do
    it 'returns the ORDER BY expression' do
      col1 = described_class.new(User, :first_name, direction: :asc)
      col2 = described_class.new(User, 'users.email', direction: :asc, distinct: true)
      col3 = described_class.new(User, :id, direction: :desc)

      expect(col1.order_sql).to eql('users.first_name asc')
      expect(col2.order_sql).to eql('users.email asc')
      expect(col3.order_sql).to eql('users.id desc')
    end

    context 'with nullable column' do
      let(:col1) { described_class.new(User, :last_name, direction: :asc, nulls: :first) }
      let(:col2) { described_class.new(User, :last_name, direction: :asc, nulls: :last) }
      let(:col3) { described_class.new(User, :last_name, direction: :desc, nulls: :first) }
      let(:col4) { described_class.new(User, :last_name, direction: :desc, nulls: :last) }

      context 'when using mysql', :mysql do
        it 'includes the NULLs sorting expression as needed' do
          expect(col1.order_sql).to eql('users.last_name asc')
          expect(col2.order_sql).to eql('users.last_name is null, users.last_name asc')
          expect(col3.order_sql).to eql('users.last_name is not null, users.last_name desc')
          expect(col4.order_sql).to eql('users.last_name desc')
        end
      end

      context 'with nullable column and using postgresql', :postgresql do
        it 'includes the NULLs sorting expression as needed' do
          expect(col1.order_sql).to eql('users.last_name asc nulls first')
          expect(col2.order_sql).to eql('users.last_name asc')
          expect(col3.order_sql).to eql('users.last_name desc')
          expect(col4.order_sql).to eql('users.last_name desc nulls last')
        end
      end

      context 'with nullable column and using sqlite', :sqlite do
        it 'includes the NULLs sorting expression as needed' do
          expect(col1.order_sql).to eql('users.last_name asc')
          expect(col2.order_sql).to eql('users.last_name asc nulls last')
          expect(col3.order_sql).to eql('users.last_name desc nulls first')
          expect(col4.order_sql).to eql('users.last_name desc')
        end
      end
    end
  end

  describe '#reversed_order_sql' do
    it 'returns the reversed ORDER BY expression' do
      col1 = described_class.new(User, :first_name, direction: :asc)
      col2 = described_class.new(User, :email, direction: :asc, distinct: true)
      col3 = described_class.new(User, :id, direction: :desc)

      expect(col1.reversed_order_sql).to eql('users.first_name desc')
      expect(col2.reversed_order_sql).to eql('users.email desc')
      expect(col3.reversed_order_sql).to eql('users.id asc')
    end

    context 'with nullable column' do
      let(:col1) { described_class.new(User, :last_name, direction: :asc, nulls: :first) }
      let(:col2) { described_class.new(User, :last_name, direction: :asc, nulls: :last) }
      let(:col3) { described_class.new(User, :last_name, direction: :desc, nulls: :first) }
      let(:col4) { described_class.new(User, :last_name, direction: :desc, nulls: :last) }

      context 'when using mysql', :mysql do
        it 'includes the NULLs sorting expression as needed' do
          expect(col1.reversed_order_sql).to eql('users.last_name desc')
          expect(col2.reversed_order_sql).to eql('users.last_name is not null, users.last_name desc')
          expect(col3.reversed_order_sql).to eql('users.last_name is null, users.last_name asc')
          expect(col4.reversed_order_sql).to eql('users.last_name asc')
        end
      end

      context 'with nullable column and using postgresql', :postgresql do
        it 'includes the NULLs sorting expression as needed' do
          expect(col1.reversed_order_sql).to eql('users.last_name desc nulls last')
          expect(col2.reversed_order_sql).to eql('users.last_name desc')
          expect(col3.reversed_order_sql).to eql('users.last_name asc')
          expect(col4.reversed_order_sql).to eql('users.last_name asc nulls first')
        end
      end

      context 'with nullable column and using sqlite', :sqlite do
        it 'includes the NULLs sorting expression as needed' do
          expect(col1.reversed_order_sql).to eql('users.last_name desc')
          expect(col2.reversed_order_sql).to eql('users.last_name desc nulls first')
          expect(col3.reversed_order_sql).to eql('users.last_name asc nulls last')
          expect(col4.reversed_order_sql).to eql('users.last_name asc')
        end
      end
    end
  end

  describe '#select_sql' do
    it 'returns the SELECT expression' do
      col1 = described_class.new(User, :first_name, direction: :asc)
      col2 = described_class.new(User, 'users.last_name', direction: :desc, nulls: :last)

      expect(col1.select_sql).to eql('users.first_name as cursor___users__first_name')
      expect(col2.select_sql).to eql('users.last_name as cursor___users__last_name')
    end
  end
end
