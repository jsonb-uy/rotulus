require 'spec_helper'

describe Rotulus::Cursor do
  before { allow(Time).to receive(:current).and_return('2023-04-01T:01:02:03'.to_time) }

  let!(:user1) { User.create(email: 'bob.dylan@email.com', first_name: 'Bob', last_name: 'Dylan') }
  let!(:user2) { User.create(email: 'jane.doe@email.com', first_name: 'Jane', last_name: 'Doe') }
  let!(:user3) { User.create(email: 'john.doe@email.com', first_name: 'John', last_name: 'Doe') }

  let(:page) do
    Rotulus::Page.new(User.all,
                      order: {
                        last_name: { direction: :desc, nulls: :first },
                        first_name: { direction: :asc }
                      },
                      limit: 2)
  end

  let(:record) do
    double(:record,
           page: page,
           values: {
             'users.first_name' => 'Jane',
             'users.last_name' => 'Doe'
           },
           state: 'somestate')
  end

  describe '.encode' do
    it 'returns a Base64-encoded cursor token' do
      data = { f: { 'users.id' => 2 },
               d: :next,
               s: 'somestate',
               c: 1_673_952_119 }

      encoded_data = described_class.encode(data)

      expect(encoded_data).to be_a(String)
    end
  end

  describe '.decode' do
    it 'returns the decoded cursor data from the given cursor token' do
      data = { f: { 'users.id' => 2 },
               d: :next,
               s: 'somestate',
               c: 1_673_952_119 }

      token = described_class.encode(data)

      expect(described_class.decode(token)).to eql(data)
    end
  end

  describe '.for_page_and_token!' do
    let!(:token) { page.next_token }

    it 'returns a cursor instance from the given page and encoded token' do
      cursor = described_class.for_page_and_token!(page, token)
      cursor_token = cursor.to_token

      expect(cursor).to be_present
      expect(cursor_token).to eql(token)

      page_at_cursor = page.at(cursor_token)
      expect(page_at_cursor.records.map(&:email)).to eql(%w[john.doe@email.com])
    end

    context 'when the cursor state from the encoded data doesn\'t match the actual cursor state' do
      it 'raises an error' do
        allow(page).to receive(:state) { 'newstate' }

        expect { described_class.for_page_and_token!(page, token) }.to raise_error(Rotulus::InvalidCursor)
      end
    end
  end

  describe '#initialize' do
    context 'when direction is not recognized' do
      it 'raises an error' do
        expect do
          described_class.new(record, 'forward')
        end.to raise_error(Rotulus::InvalidCursorDirection)

        expect do
          described_class.new(record, 'back')
        end.to raise_error(Rotulus::InvalidCursorDirection)
      end
    end

    context 'when direction is recognized' do
      it 'ensures the direction to be in symbol format' do
        cursor = described_class.new(record, 'next')
        expect(cursor.direction).to eql(:next)

        cursor = described_class.new(record, 'prev')
        expect(cursor.direction).to eql(:prev)
      end
    end

    context 'when created_at is nil' do
      subject(:cursor) { described_class.new(record, :next) }

      it 'defaults created_at to the current time' do
        expect(cursor.created_at).to eql(Time.current)
      end
    end

    context 'when created_at is not nil' do
      subject(:cursor) do
        described_class.new(record, :prev, created_at: '2023-04-01T:02:03:04'.to_time)
      end

      it 'assigns the created_at time' do
        expect(cursor.created_at).to eql('2023-04-01T:02:03:04'.to_time)
      end
    end

    context 'with cursor expiration configuration' do
      before { Rotulus.configuration.token_expires_in = 60 }

      context 'when created_at is nil' do
        it 'does not raise an error' do
          expect { described_class.new(record, :next) }.not_to raise_error
        end
      end

      context 'when the duration since the created_at time exceeds the expiration config' do
        it 'raises an error' do
          expect do
            described_class.new(record, :prev, created_at: Time.current - 61.seconds)
          end.to raise_error(Rotulus::ExpiredCursor)
        end
      end

      context 'when the duration since the created_at time does not exceed the expiration config' do
        it 'assigns the created_at time' do
          cursor = described_class.new(record, :prev, created_at: Time.current - 60.seconds)

          expect(cursor.created_at).to eql('2023-04-01T:01:01:03'.to_time)
        end
      end
    end
  end

  describe '#next?' do
    context 'when cursor direction is forward(next page)' do
      it 'returns true' do
        cursor = described_class.new(record, :next)

        expect(cursor).to be_next
      end
    end

    context 'when cursor direction is backwards(previous page)' do
      it 'returns false' do
        cursor = described_class.new(record, :prev)

        expect(cursor).not_to be_next
      end
    end
  end

  describe '#prev?' do
    context 'when cursor direction is forward(next page)' do
      it 'returns false' do
        cursor = described_class.new(record, :next)

        expect(cursor).not_to be_prev
      end
    end

    context 'when cursor direction is backwards(previous page)' do
      it 'returns true' do
        cursor = described_class.new(record, :prev)

        expect(cursor).to be_prev
      end
    end
  end

  describe '#to_token' do
    it 'returns the Base64-encoded token representation of the cursor' do
      cursor = described_class.new(record, :next, created_at: Time.current)

      token = cursor.to_token

      expect(described_class.decode(token)).to eql(
        {
          f: record.values,
          d: :next,
          s: cursor.state,
          c: cursor.created_at.to_i
        }
      )
    end
  end

  describe '#to_s' do
    it 'returns the Base64-encoded token representation of the cursor' do
      cursor = described_class.new(record, :next, created_at: Time.current)

      expect(cursor.to_s).to eql(cursor.to_token)
    end
  end

  describe '#state' do
    subject(:cursor) do
      described_class.new(record, :next, created_at: Time.current)
    end

    it "returns a string representing the combination of the page's and the cursor's state" do
      expect(cursor.state).to be_a(String)

      cursor_copy = described_class.new(record, 'next', created_at: Time.current)
      expect(cursor.state).to eql(cursor_copy.state)
    end

    context 'when the page state changed' do
      it 'returns a new state' do
        orig_state = cursor.state

        allow(page).to receive_messages(state: 'some new state')

        expect(cursor.state).not_to eql(orig_state)
      end
    end

    context 'when the reference record changed' do
      it 'returns a new state' do
        orig_state = cursor.state

        allow(cursor.record).to receive_messages(values: { 'users.first_name' => 'some value' }, state: 'newstate')

        expect(cursor.state).not_to eql(orig_state)
      end
    end

    context 'when the direction changed' do
      it 'returns a new state' do
        orig_state = cursor.state

        allow(cursor).to receive_messages(direction: :prev)

        expect(cursor.state).not_to eql(orig_state)
      end
    end

    context 'when the created_at changed' do
      it 'returns a new state' do
        orig_state = cursor.state

        allow(cursor).to receive_messages(created_at: Time.current + 1.second)

        expect(cursor.state).not_to eql(orig_state)
      end
    end

    context 'when there is no configured `secret` key' do
      it 'raises an error' do
        allow(Rotulus.configuration).to receive_messages(secret: nil)

        expect { cursor.state }.to raise_error(Rotulus::ConfigurationError)
      end
    end

    context 'when the configured `secret` key changed' do
      it 'returns a new state' do
        orig_state = cursor.state

        allow(Rotulus.configuration).to receive_messages(secret: 'new secret')

        expect(cursor.state).not_to eql(orig_state)
      end
    end
  end

  describe '#sql' do
    context 'when direction is :prev' do
      subject(:cursor) { described_class.new(second_page__first_record, :prev) }

      let(:second_page__first_record) do
        Rotulus::Record.new(page, { 'users.last_name' => user1.last_name,
                                    'users.first_name' => user1.first_name,
                                    'users.id' => user1.id })
      end

      it "returns an SQL condition to fetch the previous page's records" do
        sql = <<-SQL
          (
            users.last_name >= 'Dylan' OR users.last_name IS NULL) AND (
              (users.last_name > 'Dylan' OR users.last_name IS NULL) OR
              (users.last_name = 'Dylan' AND (
                users.first_name < 'Bob' OR (
                  users.first_name = 'Bob' AND users.id < #{user1.id}
                )
              )
            )
          )
        SQL

        expect(cursor.sql).to match_sql(sql)
      end
    end

    context 'when direction is :next' do
      subject(:cursor) { described_class.new(first_page__last_record, :next) }

      let(:first_page__last_record) do
        Rotulus::Record.new(page, { 'users.last_name' => user2.last_name,
                                    'users.first_name' => user2.first_name,
                                    'users.id' => user2.id })
      end

      it "returns an SQL condition to fetch the next page's records" do
        sql = <<-SQL
          users.last_name <= 'Doe' AND (
            users.last_name < 'Doe' OR (
              users.last_name = 'Doe' AND (
                users.first_name > 'Jane' OR (
                  users.first_name = 'Jane' AND users.id > #{user2.id}
                )
              )
            )
          )
        SQL

        expect(cursor.sql).to match_sql(sql)
      end
    end
  end
end
