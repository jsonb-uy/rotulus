require 'spec_helper'

describe Rotulus::ColumnConditionBuilder do
  describe '#build' do
    context 'when column is non-nullable and non-distinct in `asc` order' do
      let(:column) do
        Rotulus::Column.new(User, :first_name, direction: :asc)
      end

      it 'returns the correct SQL condition' do
        prev_builder = described_class.new(column, 'Juan', :prev)
        next_builder = described_class.new(column, 'Juan', :next)

        prev_sql = <<-SQL
          users.first_name < 'Juan' OR (users.first_name = 'Juan')
        SQL

        next_sql = <<-SQL
          users.first_name > 'Juan' OR (users.first_name = 'Juan')
        SQL

        expect(prev_builder.build).to match_sql(prev_sql)
        expect(next_builder.build).to match_sql(next_sql)
      end

      context 'with tie-breaker condition' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, 'Juan', :prev, 'users.id < 10')
          next_builder = described_class.new(column, 'Juan', :next, 'users.id > 10')

          prev_sql = <<-SQL
            users.first_name < 'Juan' OR (users.first_name = 'Juan' AND users.id < 10)
          SQL

          next_sql = <<-SQL
            users.first_name > 'Juan' OR (users.first_name = 'Juan' AND users.id > 10)
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end
      end
    end

    context 'when column is non-nullable and non-distinct in `desc` order' do
      let(:column) do
        Rotulus::Column.new(User, :first_name, direction: :desc)
      end

      it 'returns the correct SQL condition' do
        prev_builder = described_class.new(column, 'Juan', :prev)
        next_builder = described_class.new(column, 'Juan', :next)

        prev_sql = <<-SQL
          users.first_name > 'Juan' OR (users.first_name = 'Juan')
        SQL

        next_sql = <<-SQL
          users.first_name < 'Juan' OR (users.first_name = 'Juan')
        SQL

        expect(prev_builder.build).to match_sql(prev_sql)
        expect(next_builder.build).to match_sql(next_sql)
      end

      context 'with tie-breaker condition' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, 'Juan', :prev, 'users.id < 10')
          next_builder = described_class.new(column, 'Juan', :next, 'users.id > 10')

          prev_sql = <<-SQL
            users.first_name > 'Juan' OR (users.first_name = 'Juan' AND users.id < 10)
          SQL

          next_sql = <<-SQL
            users.first_name < 'Juan' OR (users.first_name = 'Juan' AND users.id > 10)
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end
      end
    end

    context 'when column is non-nullable and distinct in `asc` order' do
      let(:column) do
        Rotulus::Column.new(User, :email, direction: :asc, distinct: true)
      end

      it 'returns the correct SQL condition' do
        prev_builder = described_class.new(column, 'user@email.com', :prev)
        next_builder = described_class.new(column, 'user@email.com', :next)

        prev_sql = <<-SQL
          users.email < 'user@email.com'
        SQL

        next_sql = <<-SQL
          users.email > 'user@email.com'
        SQL

        expect(prev_builder.build).to match_sql(prev_sql)
        expect(next_builder.build).to match_sql(next_sql)
      end

      context 'with tie-breaker condition' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, 'user@email.com', :prev, 'users.id < 10')
          next_builder = described_class.new(column, 'user@email.com', :next, 'users.id < 10')

          prev_sql = <<-SQL
            users.email < 'user@email.com'
          SQL

          next_sql = <<-SQL
            users.email > 'user@email.com'
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end
      end
    end

    context 'when column is non-nullable and distinct in `desc` order' do
      let(:column) do
        Rotulus::Column.new(User, :email, direction: :desc, distinct: true)
      end

      it 'returns the correct SQL condition' do
        prev_builder = described_class.new(column, 'user@email.com', :prev)
        next_builder = described_class.new(column, 'user@email.com', :next)

        prev_sql = <<-SQL
          users.email > 'user@email.com'
        SQL

        next_sql = <<-SQL
          users.email < 'user@email.com'
        SQL

        expect(prev_builder.build).to match_sql(prev_sql)
        expect(next_builder.build).to match_sql(next_sql)
      end

      context 'with tie-breaker condition' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, 'user@email.com', :prev, 'users.id < 10')
          next_builder = described_class.new(column, 'user@email.com', :next, 'users.id < 10')

          prev_sql = <<-SQL
            users.email > 'user@email.com'
          SQL

          next_sql = <<-SQL
            users.email < 'user@email.com'
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end
      end
    end

    context 'when column is nullable and non-distinct in `asc nulls first` order' do
      let(:column) do
        Rotulus::Column.new(User, :last_name, direction: :asc, nulls: :first)
      end

      context 'when column value is nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, nil, :prev)
          next_builder = described_class.new(column, nil, :next)

          prev_sql = <<-SQL
            users.last_name IS NULL
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL)
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, nil, :prev, 'users.id < 10')
            next_builder = described_class.new(column, nil, :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.last_name IS NULL AND users.id < 10
            SQL

            next_sql = <<-SQL
              users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id > 10)
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end

      context 'when column value is not nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, 'Dela cruz', :prev)
          next_builder = described_class.new(column, 'Dela cruz', :next)

          prev_sql = <<-SQL
            (users.last_name < 'Dela cruz' OR users.last_name IS NULL) OR
              (users.last_name = 'Dela cruz')
          SQL

          next_sql = <<-SQL
            users.last_name > 'Dela cruz' OR (users.last_name = 'Dela cruz')
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, 'Dela cruz', :prev, 'users.id < 10')
            next_builder = described_class.new(column, 'Dela cruz', :next, 'users.id > 10')

            prev_sql = <<-SQL
              (users.last_name < 'Dela cruz' OR users.last_name IS NULL) OR
              (users.last_name = 'Dela cruz' AND users.id < 10)
            SQL

            next_sql = <<-SQL
              users.last_name > 'Dela cruz' OR (users.last_name = 'Dela cruz' AND users.id > 10)
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end
    end

    context 'when column is nullable and non-distinct in `asc nulls last` order' do
      let(:column) do
        Rotulus::Column.new(User, :last_name, direction: :asc, nulls: :last)
      end

      context 'when column value is nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, nil, :prev)
          next_builder = described_class.new(column, nil, :next)

          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL)
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, nil, :prev, 'users.id < 10')
            next_builder = described_class.new(column, nil, :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id < 10)
            SQL

            next_sql = <<-SQL
              users.last_name IS NULL AND users.id > 10
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end

      context 'when column value is not nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, 'Dela cruz', :prev)
          next_builder = described_class.new(column, 'Dela cruz', :next)

          prev_sql = <<-SQL
            users.last_name < 'Dela cruz' OR (users.last_name = 'Dela cruz')
          SQL

          next_sql = <<-SQL
            (users.last_name > 'Dela cruz' OR users.last_name IS NULL) OR
              (users.last_name = 'Dela cruz')
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, 'Dela cruz', :prev, 'users.id < 10')
            next_builder = described_class.new(column, 'Dela cruz', :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.last_name < 'Dela cruz' OR (users.last_name = 'Dela cruz' AND users.id < 10)
            SQL

            next_sql = <<-SQL
              (users.last_name > 'Dela cruz' OR users.last_name IS NULL) OR
              (users.last_name = 'Dela cruz' AND users.id > 10)
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end
    end

    context 'when column is nullable and non-distinct in `desc nulls first` order' do
      let(:column) do
        Rotulus::Column.new(User, :last_name, direction: :desc, nulls: :first)
      end

      context 'when column value is nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, nil, :prev)
          next_builder = described_class.new(column, nil, :next)

          prev_sql = <<-SQL
            users.last_name IS NULL
          SQL

          next_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL)
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, nil, :prev, 'users.id < 10')
            next_builder = described_class.new(column, nil, :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.last_name IS NULL AND users.id < 10
            SQL

            next_sql = <<-SQL
              users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id > 10)
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end

      context 'when column value is not nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, 'Dela cruz', :prev)
          next_builder = described_class.new(column, 'Dela cruz', :next)

          prev_sql = <<-SQL
            (users.last_name > 'Dela cruz' OR users.last_name IS NULL) OR
              (users.last_name = 'Dela cruz')
          SQL

          next_sql = <<-SQL
            users.last_name < 'Dela cruz' OR (users.last_name = 'Dela cruz')
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, 'Dela cruz', :prev, 'users.id < 10')
            next_builder = described_class.new(column, 'Dela cruz', :next, 'users.id > 10')

            prev_sql = <<-SQL
              (users.last_name > 'Dela cruz' OR users.last_name IS NULL) OR
              (users.last_name = 'Dela cruz' AND users.id < 10)
            SQL

            next_sql = <<-SQL
              users.last_name < 'Dela cruz' OR (users.last_name = 'Dela cruz' AND users.id > 10)
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end
    end

    context 'when column is nullable and non-distinct in `desc nulls last` order' do
      let(:column) do
        Rotulus::Column.new(User, :last_name, direction: :desc, nulls: :last)
      end

      context 'when column value is nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, nil, :prev)
          next_builder = described_class.new(column, nil, :next)

          prev_sql = <<-SQL
            users.last_name IS NOT NULL OR (users.last_name IS NULL)
          SQL

          next_sql = <<-SQL
            users.last_name IS NULL
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, nil, :prev, 'users.id < 10')
            next_builder = described_class.new(column, nil, :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.last_name IS NOT NULL OR (users.last_name IS NULL AND users.id < 10)
            SQL

            next_sql = <<-SQL
              users.last_name IS NULL AND users.id > 10
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end

      context 'when column value is not nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, 'Dela cruz', :prev)
          next_builder = described_class.new(column, 'Dela cruz', :next)

          prev_sql = <<-SQL
            users.last_name > 'Dela cruz' OR (users.last_name = 'Dela cruz')
          SQL

          next_sql = <<-SQL
            (users.last_name < 'Dela cruz' OR users.last_name IS NULL) OR
              (users.last_name = 'Dela cruz')
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, 'Dela cruz', :prev, 'users.id < 10')
            next_builder = described_class.new(column, 'Dela cruz', :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.last_name > 'Dela cruz' OR (users.last_name = 'Dela cruz' AND users.id < 10)
            SQL

            next_sql = <<-SQL
              (users.last_name < 'Dela cruz' OR users.last_name IS NULL) OR
              (users.last_name = 'Dela cruz' AND users.id > 10)
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end
    end

    context 'when column is nullable and distinct in `asc nulls first` order' do
      let(:column) do
        Rotulus::Column.new(User, :ssn, direction: :asc, distinct: true, nulls: :first)
      end

      context 'when column value is nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, nil, :prev)
          next_builder = described_class.new(column, nil, :next)

          prev_sql = <<-SQL
            users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL)
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, nil, :prev, 'users.id < 10')
            next_builder = described_class.new(column, nil, :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.ssn IS NULL AND users.id < 10
            SQL

            next_sql = <<-SQL
              users.ssn IS NOT NULL OR (users.ssn IS NULL AND users.id > 10)
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end

      context 'when column value is not nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, '192-6464-0192', :prev)
          next_builder = described_class.new(column, '192-6464-0192', :next)

          prev_sql = <<-SQL
            users.ssn < '192-6464-0192' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn > '192-6464-0192'
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, '192-6464-0192', :prev, 'users.id < 10')
            next_builder = described_class.new(column, '192-6464-0192', :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.ssn < '192-6464-0192' OR users.ssn IS NULL
            SQL

            next_sql = <<-SQL
              users.ssn > '192-6464-0192'
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end
    end

    context 'when column is nullable and distinct in `asc nulls last` order' do
      let(:column) do
        Rotulus::Column.new(User, :ssn, direction: :asc, distinct: true, nulls: :last)
      end

      context 'when column value is nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, nil, :prev)
          next_builder = described_class.new(column, nil, :next)

          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL)
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, nil, :prev, 'users.id < 10')
            next_builder = described_class.new(column, nil, :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.ssn IS NOT NULL OR (users.ssn IS NULL AND users.id < 10)
            SQL

            next_sql = <<-SQL
              users.ssn IS NULL AND users.id > 10
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end

      context 'when column value is not nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, '192-6464-0192', :prev)
          next_builder = described_class.new(column, '192-6464-0192', :next)

          prev_sql = <<-SQL
            users.ssn < '192-6464-0192'
          SQL

          next_sql = <<-SQL
            users.ssn > '192-6464-0192' OR users.ssn IS NULL
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, '192-6464-0192', :prev, 'users.id < 10')
            next_builder = described_class.new(column, '192-6464-0192', :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.ssn < '192-6464-0192'
            SQL

            next_sql = <<-SQL
              users.ssn > '192-6464-0192' OR users.ssn IS NULL
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end
    end

    context 'when column is nullable and distinct in `desc nulls first` order' do
      let(:column) do
        Rotulus::Column.new(User, :ssn, direction: :desc, distinct: true, nulls: :first)
      end

      context 'when column value is nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, nil, :prev)
          next_builder = described_class.new(column, nil, :next)

          prev_sql = <<-SQL
            users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL)
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, nil, :prev, 'users.id < 10')
            next_builder = described_class.new(column, nil, :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.ssn IS NULL AND users.id < 10
            SQL

            next_sql = <<-SQL
              users.ssn IS NOT NULL OR (users.ssn IS NULL AND users.id > 10)
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end

      context 'when column value is not nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, '192-6464-0192', :prev)
          next_builder = described_class.new(column, '192-6464-0192', :next)

          prev_sql = <<-SQL
            users.ssn > '192-6464-0192' OR users.ssn IS NULL
          SQL

          next_sql = <<-SQL
            users.ssn < '192-6464-0192'
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, '192-6464-0192', :prev, 'users.id < 10')
            next_builder = described_class.new(column, '192-6464-0192', :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.ssn > '192-6464-0192' OR users.ssn IS NULL
            SQL

            next_sql = <<-SQL
              users.ssn < '192-6464-0192'
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end
    end

    context 'when column is nullable and distinct in `desc nulls last` order' do
      let(:column) do
        Rotulus::Column.new(User, :ssn, direction: :desc, distinct: true, nulls: :last)
      end

      context 'when column value is nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, nil, :prev)
          next_builder = described_class.new(column, nil, :next)

          prev_sql = <<-SQL
            users.ssn IS NOT NULL OR (users.ssn IS NULL)
          SQL

          next_sql = <<-SQL
            users.ssn IS NULL
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, nil, :prev, 'users.id < 10')
            next_builder = described_class.new(column, nil, :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.ssn IS NOT NULL OR (users.ssn IS NULL AND users.id < 10)
            SQL

            next_sql = <<-SQL
              users.ssn IS NULL AND users.id > 10
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end

      context 'when column value is not nil' do
        it 'returns the correct SQL condition' do
          prev_builder = described_class.new(column, '192-6464-0192', :prev)
          next_builder = described_class.new(column, '192-6464-0192', :next)

          prev_sql = <<-SQL
            users.ssn > '192-6464-0192'
          SQL

          next_sql = <<-SQL
            users.ssn < '192-6464-0192' OR users.ssn IS NULL
          SQL

          expect(prev_builder.build).to match_sql(prev_sql)
          expect(next_builder.build).to match_sql(next_sql)
        end

        context 'with tie-breaker condition' do
          it 'returns the correct SQL condition' do
            prev_builder = described_class.new(column, '192-6464-0192', :prev, 'users.id < 10')
            next_builder = described_class.new(column, '192-6464-0192', :next, 'users.id > 10')

            prev_sql = <<-SQL
              users.ssn > '192-6464-0192'
            SQL

            next_sql = <<-SQL
              users.ssn < '192-6464-0192' OR users.ssn IS NULL
            SQL

            expect(prev_builder.build).to match_sql(prev_sql)
            expect(next_builder.build).to match_sql(next_sql)
          end
        end
      end
    end
  end
end
