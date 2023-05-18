require 'spec_helper'
require 'securerandom'

describe Rotulus::Page do
  subject(:page) do
    described_class.new(
      User.where.not(first_name: 'Excluded'),
      order: order,
      limit: 3
    )
  end

  let(:order) do
    {
      first_name: { direction: :asc },
      last_name: { direction: :desc },
      email: { direction: :asc }
    }
  end

  before { User.create_test_data }

  describe '#as_table' do
    it 'returns a string showing the current page\'s records in table format' do
      table = <<-TEXT
        +-----------------------------------------------------------------------------------------+
        |   users.first_name   |   users.last_name   |        users.email         |   users.id    |
        +-----------------------------------------------------------------------------------------+
        |        George        |       <NULL>        |     george@domain.com      |   {anything}  |
        |         Jane         |        Smith        |   jane.c.smith@email.com   |   {anything}  |
        |         Jane         |         Doe         |     jane.doe@email.com     |   {anything}  |
        +-----------------------------------------------------------------------------------------+
      TEXT

      expect(page.as_table).to be_a(String)
      expect(page.as_table).to match_table(table)
    end
  end

  context 'when order is not defined' do
    it 'does not raise an error' do
      expect { described_class.new(User.all, order: nil) }.not_to raise_error
    end

    it 'defaults order by primary key in ascending order' do
      page = described_class.new(User.all, order: nil)

      expect(page.order.sql).to eql('users.id asc')
    end
  end

  context 'when limit is less than 0' do
    it 'raises an error' do
      expect { described_class.new(User.all, limit: -1) }.to raise_error(
        Rotulus::InvalidLimit
      )
    end
  end

  context 'when limit is 0' do
    it 'raises an error' do
      expect { described_class.new(User.all, limit: 0) }.to raise_error(
        Rotulus::InvalidLimit
      )
    end
  end

  context 'when limit exceeds the :page_max_limit configuration' do
    before { allow(Rotulus.configuration).to receive_messages(page_max_limit: 10) }

    it 'raises an error' do
      expect { described_class.new(User.all, limit: 11) }.to raise_error(
        Rotulus::InvalidLimit
      )
    end
  end

  context 'when limit is nil' do
    context 'with configured page_default_limit' do
      before { Rotulus.configuration.page_default_limit = 3 }

      it 'defaults to the configured page_default_limit' do
        page = described_class.new(User.all, limit: nil)

        expect(page.limit).to eql(3)
      end
    end

    context 'with no configured page_default_limit' do
      before { Rotulus.configuration.page_default_limit = nil }

      it 'defaults to 5' do
        page = described_class.new(User.all, limit: nil)

        expect(page.limit).to eql(5)
      end
    end
  end

  context 'when limit is an empty string' do
    context 'with configured page_default_limit' do
      before { Rotulus.configuration.page_default_limit = 4 }

      it 'defaults to the configured page_default_limit' do
        page = described_class.new(User.all, limit: ' ')

        expect(page.limit).to eql(4)
      end
    end

    context 'with no configured page_default_limit' do
      before { Rotulus.configuration.page_default_limit = nil }

      it 'defaults to 5' do
        page = described_class.new(User.all, limit: '')

        expect(page.limit).to eql(5)
      end
    end
  end

  describe '#at' do
    context 'with nil token' do
      it 'returns a new root Page' do
        second_page = page.next
        page_at_cursor = second_page.at(nil)

        expect(second_page).not_to be_root
        expect(page_at_cursor).to be_root
        expect(page_at_cursor).not_to eql(page)
        expect(page_at_cursor.records.map(&:email)).to eql(
          %w[george@domain.com jane.c.smith@email.com jane.doe@email.com]
        )
      end
    end

    context 'with token' do
      it 'returns a new Page pointed at the given cursor token' do
        next_token = page.next_token
        page_at_cursor = page.at(next_token)

        expect(page).to be_root
        expect(page_at_cursor).not_to be_root
        expect(page_at_cursor).not_to eql(page)
        expect(page_at_cursor.records.map(&:email)).to eql(
          %w[john.doe@email.com johnny.apple@email.com paul@domain.com]
        )
      end
    end
  end

  describe '#at!' do
    context 'with nil token' do
      it 'points the page to the root' do
        second_page = page.next
        page_at_cursor = second_page.at!(nil)

        expect(second_page).to be_root
        expect(page_at_cursor).to be_root
        expect(page_at_cursor).not_to eql(page)
        expect(page_at_cursor.records.map(&:email)).to eql(
          %w[george@domain.com jane.c.smith@email.com jane.doe@email.com]
        )
      end
    end

    context 'with token' do
      it 'points the page to the cursor' do
        next_token = page.next_token
        page_at_cursor = page.at!(next_token)

        expect(page).not_to be_root
        expect(page_at_cursor).not_to be_root
        expect(page_at_cursor).to eql(page)
        expect(page_at_cursor.records.map(&:email)).to eql(
          %w[john.doe@email.com johnny.apple@email.com paul@domain.com]
        )
      end
    end
  end

  describe '#records' do
    context 'when records exist for the current page' do
      it 'returns the sorted records for the page' do
        expect(page.records.map(&:email)).to eql(
          %w[george@domain.com jane.c.smith@email.com jane.doe@email.com]
        )

        expect(page.next.records.map(&:email)).to eql(
          %w[john.doe@email.com johnny.apple@email.com paul@domain.com]
        )

        expect(page.next.next.records.map(&:email)).to eql(
          %w[ringo@domain.com rory.gallagher@email.com]
        )
      end
    end

    context 'when there are no records' do
      subject(:page) do
        described_class.new(User.where(first_name: 'no matching record'), limit: 3)
      end

      it 'returns an empty array' do
        expect(page.records).to eql([])
      end
    end
  end

  describe '#reload' do
    it 'clears memoized records' do
      orig_count = page.records.size

      User.destroy_all

      expect(page.reload.records.size).not_to eql(orig_count)
    end

    it 'returns the same page' do
      expect(page.reload).to eql(page)
    end
  end

  describe '#next?' do
    context 'when records exist for the current page' do
      it 'returns true if there is a next page' do
        expect(page.next?).to be(true)
        expect(page.next.prev.next?).to be(true)

        expect(page.next.next?).to be(true)
        expect(page.next.next.prev.next?).to be(true)
      end

      it 'returns false if there is no next page' do
        expect(page.next.next.next?).to be(false)
      end
    end

    context 'when there are no records' do
      subject(:page) do
        described_class.new(User.where(first_name: 'no matching record'), limit: 3)
      end

      it 'returns false' do
        expect(page.next?).to be(false)
      end
    end
  end

  describe '#prev?' do
    context 'when records exist for the current page' do
      it 'returns true if there is a previous page' do
        expect(page.next.prev?).to be(true)
        expect(page.next.next.prev.prev?).to be(true)

        expect(page.next.next.prev?).to be(true)
      end

      it 'returns false if there is no previous page' do
        expect(page.prev?).to be(false)
        expect(page.next.prev.prev?).to be(false)
      end
    end

    context 'when there are no records' do
      subject(:page) do
        described_class.new(User.where(first_name: 'no matching record'), limit: 3)
      end

      it 'returns false' do
        expect(page.prev?).to be(false)
      end
    end
  end

  describe '#root?' do
    it 'returns true if there is no previous page' do
      expect(page).to be_root
      expect(page.next.prev).to be_root
      expect(page.next.next.prev.prev).to be_root
    end

    it 'returns false if there is a previous page' do
      expect(page.next).not_to be_root
      expect(page.next.next.prev).not_to be_root
      expect(page.next.next).not_to be_root
    end
  end

  describe '#next_token' do
    context 'when records exist for the current page' do
      context 'when there is a next page' do
        it 'returns the cursor token to access the next page' do
          second_page_token = page.next_token
          third_page_token = page.next.next_token

          expect(second_page_token).to be_present
          expect(page.at(second_page_token).records.map(&:email)).to eql(
            %w[john.doe@email.com johnny.apple@email.com paul@domain.com]
          )

          expect(third_page_token).to be_present
          expect(page.at(third_page_token).records.map(&:email)).to eql(
            %w[ringo@domain.com rory.gallagher@email.com]
          )
        end
      end

      context 'when there is no next page' do
        it 'returns nil' do
          fourth_page_token = page.next.next.next_token

          expect(fourth_page_token).to be_nil
        end
      end
    end

    context 'when there are no records' do
      subject(:page) do
        described_class.new(User.where(first_name: 'no matching record'), limit: 3)
      end

      it 'returns nil' do
        expect(page.next_token).to be_nil
      end
    end
  end

  describe '#prev_token' do
    context 'when records exist for the current page' do
      context 'when there is a previous page' do
        it 'returns the cursor token to access the previous page' do
          root_page_token = page.next.prev_token
          second_page_token = page.next.next.prev_token

          expect(root_page_token).to be_present
          expect(page.at(root_page_token).records.map(&:email)).to eql(
            %w[george@domain.com jane.c.smith@email.com jane.doe@email.com]
          )

          expect(second_page_token).to be_present
          expect(page.at(second_page_token).records.map(&:email)).to eql(
            %w[john.doe@email.com johnny.apple@email.com paul@domain.com]
          )
        end
      end

      context 'when there is no previous page' do
        it 'returns nil' do
          expect(page.prev_token).to be_nil
          expect(page.next.prev.prev_token).to be_nil
        end
      end
    end

    context 'when there are no records' do
      subject(:page) do
        described_class.new(User.where(first_name: 'no matching record'), limit: 3)
      end

      it 'returns nil' do
        expect(page.prev_token).to be_nil
      end
    end
  end

  describe '#next' do
    context 'when records exist for the current page' do
      context 'when there is a next page' do
        it 'returns the next page' do
          expect(page.next.records.map(&:email)).to eql(
            %w[john.doe@email.com johnny.apple@email.com paul@domain.com]
          )

          expect(page.next.next.records.map(&:email)).to eql(
            %w[ringo@domain.com rory.gallagher@email.com]
          )
        end
      end

      context 'when there is no next page' do
        it 'returns nil' do
          third_page = page.next.next

          expect(third_page.next).to be_nil
        end
      end
    end

    context 'when there are no records' do
      subject(:page) do
        described_class.new(User.where(first_name: 'no matching record'), limit: 3)
      end

      it 'returns nil' do
        expect(page.next).to be_nil
      end
    end
  end

  describe '#prev' do
    context 'when records exist for the current page' do
      context 'when there is a previous page' do
        it 'returns the previous page' do
          expect(page.next.prev.records.map(&:email)).to eql(
            %w[george@domain.com jane.c.smith@email.com jane.doe@email.com]
          )

          expect(page.next.next.prev.records.map(&:email)).to eql(
            %w[john.doe@email.com johnny.apple@email.com paul@domain.com]
          )
        end
      end

      context 'when there is no previous page' do
        it 'returns nil' do
          expect(page.prev).to be_nil
          expect(page.next.prev.prev).to be_nil
        end
      end
    end

    context 'when there are no records' do
      subject(:page) do
        described_class.new(User.where(first_name: 'no matching record'), limit: 3)
      end

      it 'returns nil' do
        expect(page.prev).to be_nil
      end
    end
  end

  describe '#links' do
    context 'with no previous page and no next page' do
      it 'returns an empty hash' do
        page = described_class.new(User.where(first_name: 'no matches'))

        expect(page.links).to eql({})
      end
    end

    context 'with previous page and no next page' do
      it 'returns a hash with a token for the previous page' do
        last_page = page.next.next

        expect(last_page.links).to eql({ previous: last_page.prev_token })
      end
    end

    context 'with previous page and with next page' do
      it 'returns a hash with a token for the previous and next page' do
        second_page = page.next

        expect(second_page.links).to eql({ previous: second_page.prev_token,
                                           next: second_page.next_token })
      end
    end

    context 'with no previous page and with next page' do
      it 'returns a hash with a token for the next page' do
        expect(page.links).to eql({ next: page.next_token })
      end
    end
  end

  describe '#state' do
    it "returns a string representing the page's filtering, sorting, and limit state" do
      expect(page.state).to be_present
      expect(page.state).to be_a(String)

      page_copy = described_class.new(page.ar_relation, order: order, limit: page.limit)
      expect(page.state).to eql(page_copy.state)
    end

    context 'when AR filter changed' do
      it 'returns a new state' do
        page_copy = described_class.new(page.ar_relation.where(first_name: 'not exluded'),
                                        order: order, limit: page.limit)
        expect(page_copy.state).not_to eql(page.state)
      end
    end

    context 'when sorting changed' do
      it 'returns a new state' do
        page_copy = described_class.new(page.ar_relation,
                                        order: {
                                          first_name: {
                                            direction: :desc
                                          }
                                        },
                                        limit: page.limit)

        expect(page_copy.state).not_to eql(page.state)
      end
    end

    context 'when limit changed' do
      it 'returns a new state' do
        page_copy = described_class.new(page.ar_relation, order: order, limit: page.limit + 1)

        expect(page_copy.state).not_to eql(page.state)
      end
    end
  end

  context 'when paginating records' do
    context 'with null values' do
      before do
        User.create(email: 'a@somedomain.com', first_name: 'A', last_name: 'A', ssn: '12')
        User.create(email: 'b@somedomain.com', first_name: 'B')
        User.create(email: 'ab@somedomain.com', first_name: 'A', ssn: '012')
        User.create(email: 'ac@somedomain.com', first_name: 'A')
        User.create(email: 'ab2@somedomain.com', first_name: 'B', last_name: 'A', ssn: '13')
        User.create(email: 'ab3@somedomain.com', first_name: 'B', last_name: 'A', ssn: '14')
        User.create(email: 'c3@somedomain.com', first_name: 'C', ssn: '26')
        User.create(email: 'c2@somedomain.com', first_name: 'C')
        User.create(email: 'c1@somedomain.com', first_name: 'C', ssn: '25')
        User.create(email: 'd13@somedomain.com', first_name: 'DB', last_name: 'D')
        User.create(email: 'd12@somedomain.com', first_name: 'DA', last_name: 'D')
      end

      context 'with nulls :first' do
        subject(:page) do
          described_class.new(
            User.where("email like '%@somedomain.com'"),
            order: {
              last_name: { direction: :asc, nulls: :first },
              first_name: { direction: :desc },
              ssn: { direction: :desc, nulls: :first, distinct: true },
              email: { direction: :asc }
            },
            limit: 2
          )
        end

        it 'correctly paginates the records' do
          page1_table = <<-TEXT
            +----------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |   users.email   |   users.id    |
            +----------------------------------------------------------------------------------------------+
            |       <NULL>        |          C           |    <NULL>     |c2@somedomain.com|   {anything}  |
            |       <NULL>        |          C           |      26       |c3@somedomain.com|   {anything}  |
            +----------------------------------------------------------------------------------------------+
          TEXT

          page2_table = <<-TEXT
            +----------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |   users.email   |   users.id    |
            +----------------------------------------------------------------------------------------------+
            |       <NULL>        |          C           |      25       |c1@somedomain.com|   {anything}  |
            |       <NULL>        |          B           |    <NULL>     |b@somedomain.com |   {anything}  |
            +----------------------------------------------------------------------------------------------+
          TEXT

          page3_table = <<-TEXT
            +----------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |   users.email   |   users.id    |
            +----------------------------------------------------------------------------------------------+
            |       <NULL>        |          A           |    <NULL>     |ac@somedomain.com|   {anything}  |
            |       <NULL>        |          A           |      012      |ab@somedomain.com|   {anything}  |
            +----------------------------------------------------------------------------------------------+
          TEXT

          page4_table = <<-TEXT
            +-----------------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |      users.email       |   users.id    |
            +-----------------------------------------------------------------------------------------------------+
            |          A          |          B           |      14       |   ab3@somedomain.com   |  {anything}   |
            |          A          |          B           |      13       |   ab2@somedomain.com   |  {anything}   |
            +-----------------------------------------------------------------------------------------------------+
          TEXT

          page5_table = <<-TEXT
            +-----------------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |      users.email       |   users.id    |
            +-----------------------------------------------------------------------------------------------------+
            |          A          |          A           |      12       |    a@somedomain.com    |  {anything}   |
            |          D          |          DB          |    <NULL>     |   d13@somedomain.com   |  {anything}   |
            +-----------------------------------------------------------------------------------------------------+
          TEXT

          page6_table = <<-TEXT
            +-----------------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |      users.email       |   users.id    |
            +-----------------------------------------------------------------------------------------------------+
            |          D          |          DA          |    <NULL>     |   d12@somedomain.com   |  {anything}   |
            +-----------------------------------------------------------------------------------------------------+
          TEXT

          page1 = page
          page2 = page1.next
          page3 = page2.next
          page4 = page3.next
          page5 = page4.next
          page6 = page5.next

          expect(page1.as_table).to match_table(page1_table)
          expect(page2.as_table).to match_table(page2_table)
          expect(page3.as_table).to match_table(page3_table)
          expect(page4.as_table).to match_table(page4_table)
          expect(page5.as_table).to match_table(page5_table)
          expect(page6.as_table).to match_table(page6_table)

          expect(page2.prev.as_table).to match_table(page1_table)
          expect(page3.prev.as_table).to match_table(page2_table)
          expect(page4.prev.as_table).to match_table(page3_table)
          expect(page5.prev.as_table).to match_table(page4_table)
          expect(page6.prev.as_table).to match_table(page5_table)
        end
      end

      context 'with nulls :last' do
        subject(:page) do
          described_class.new(
            User.where("email like '%@somedomain.com'"),
            order: {
              last_name: { direction: :asc, nulls: :last },
              first_name: { direction: :desc },
              ssn: { direction: :desc, nulls: :last, distinct: true },
              email: { direction: :asc }
            },
            limit: 2
          )
        end

        it 'correctly paginates the records' do
          page1_table = <<-TEXT
            +-----------------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |      users.email       |   users.id    |
            +-----------------------------------------------------------------------------------------------------+
            |          A          |          B           |      14       |   ab3@somedomain.com   |  {anything}   |
            |          A          |          B           |      13       |   ab2@somedomain.com   |  {anything}   |
            +-----------------------------------------------------------------------------------------------------+
          TEXT

          page2_table = <<-TEXT
            +-----------------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |      users.email       |   users.id    |
            +-----------------------------------------------------------------------------------------------------+
            |          A          |          A           |      12       |    a@somedomain.com    |  {anything}   |
            |          D          |          DB          |    <NULL>     |   d13@somedomain.com   |  {anything}   |
            +-----------------------------------------------------------------------------------------------------+
          TEXT

          page3_table = <<-TEXT
            +-----------------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |      users.email       |   users.id    |
            +-----------------------------------------------------------------------------------------------------+
            |          D          |          DA          |    <NULL>     |   d12@somedomain.com   |  {anything}   |
            |       <NULL>        |          C           |      26       |   c3@somedomain.com    |   {anything}  |
            +-----------------------------------------------------------------------------------------------------+
          TEXT

          page4_table = <<-TEXT
            +--------------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |     users.email     |   users.id    |
            +--------------------------------------------------------------------------------------------------+
            |       <NULL>        |          C           |      25       |  c1@somedomain.com  |   {anything}  |
            |       <NULL>        |          C           |    <NULL>     |  c2@somedomain.com  |   {anything}  |
            +--------------------------------------------------------------------------------------------------+
          TEXT

          page5_table = <<-TEXT
            +------------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |   users.email     |   users.id    |
            +------------------------------------------------------------------------------------------------+
            |       <NULL>        |          B           |    <NULL>     | b@somedomain.com  |   {anything}  |
            |       <NULL>        |          A           |      012      | ab@somedomain.com |   {anything}  |
            +------------------------------------------------------------------------------------------------+
          TEXT

          page6_table = <<-TEXT
            +----------------------------------------------------------------------------------------------+
            |   users.last_name   |   users.first_name   |   users.ssn   |   users.email   |   users.id    |
            +----------------------------------------------------------------------------------------------+
            |       <NULL>        |          A           |    <NULL>     |ac@somedomain.com|   {anything}  |
            +----------------------------------------------------------------------------------------------+
          TEXT

          page1 = page
          page2 = page1.next
          page3 = page2.next
          page4 = page3.next
          page5 = page4.next
          page6 = page5.next

          expect(page1.as_table).to match_table(page1_table)
          expect(page2.as_table).to match_table(page2_table)
          expect(page3.as_table).to match_table(page3_table)
          expect(page4.as_table).to match_table(page4_table)
          expect(page5.as_table).to match_table(page5_table)
          expect(page6.as_table).to match_table(page6_table)

          expect(page2.prev.as_table).to match_table(page1_table)
          expect(page3.prev.as_table).to match_table(page2_table)
          expect(page4.prev.as_table).to match_table(page3_table)
          expect(page5.prev.as_table).to match_table(page4_table)
          expect(page6.prev.as_table).to match_table(page5_table)
        end
      end
    end

    context 'with datetime values' do
      before do
        User.create(email: 'a@somedomain.com', first_name: 'A', member_since: '2023-04-01T08:09:00+07:00')
        User.create(email: 'b@somedomain.com', first_name: 'B', member_since: '2023-04-01T08:09:00-09:00')
        User.create(email: 'ab@somedomain.com', first_name: 'A', member_since: '2023-04-01T08:09:00+08:00')
        User.create(email: 'ac@somedomain.com', first_name: 'A', member_since: '2023-04-01T01:02:00+07:00')
        User.create(email: 'ab2@somedomain.com', first_name: 'B', member_since: '2023-04-02T01:09:01+08:00')
        User.create(email: 'ab3@somedomain.com', first_name: 'B', member_since: '2023-04-01T08:09:00+08:00')
        User.create(email: 'c3@somedomain.com', first_name: 'C', member_since: '2023-04-01T08:02:00+07:00')
        User.create(email: 'c2@somedomain.com', first_name: 'C', member_since: '2023-04-01T08:02:00+07:00')
        User.create(email: 'c1@somedomain.com', first_name: 'C', member_since: '2023-04-01T08:02:00+00:00')
        User.create(email: 'd13@somedomain.com', first_name: 'D', member_since: '2022-11-01T07:19:00+07:00')
        User.create(email: 'd12@somedomain.com', first_name: 'D', member_since: '2022-01-01T01:09:00+07:00')
      end

      subject(:page) do
        described_class.new(
          User.where("email like '%@somedomain.com'"),
          order: {
            first_name: { direction: :asc },
            member_since: { direction: :desc },
            email: { direction: :desc }
          },
          limit: 2
        )
      end

      it 'correctly paginates the records' do
        page1_table = <<-TEXT
          +---------------------------------------------------------------------------------------+
          |   users.first_name   |   users.member_since   |      users.email      |   users.id    |
          +---------------------------------------------------------------------------------------+
          |          A           |2023-04-01T01:09:00.000Z|   a@somedomain.com    |  {anything}   |
          |          A           |2023-04-01T00:09:00.000Z|   ab@somedomain.com   |  {anything}   |
          +---------------------------------------------------------------------------------------+
        TEXT

        page2_table = <<-TEXT
          +---------------------------------------------------------------------------------------+
          |   users.first_name   |   users.member_since   |      users.email      |   users.id    |
          +---------------------------------------------------------------------------------------+
          |          A           |2023-03-31T18:02:00.000Z|   ac@somedomain.com   |  {anything}   |
          |          B           |2023-04-01T17:09:01.000Z|  ab2@somedomain.com   |  {anything}   |
          +---------------------------------------------------------------------------------------+
        TEXT

        page3_table = <<-TEXT
          +-----------------------------------------------------------------------------+
          | users.first_name |   users.member_since    |    users.email     | users.id  |
          +-----------------------------------------------------------------------------+
          |        B         | 2023-04-01T17:09:00.000Z|  b@somedomain.com  | {anything}|
          |        B         | 2023-04-01T00:09:00.000Z| ab3@somedomain.com | {anything}|
          +-----------------------------------------------------------------------------+
        TEXT

        page4_table = <<-TEXT
          +----------------------------------------------------------------------------+
          | users.first_name |   users.member_since    |    users.email    | users.id  |
          +----------------------------------------------------------------------------+
          |        C         | 2023-04-01T08:02:00.000Z| c1@somedomain.com | {anything}|
          |        C         | 2023-04-01T01:02:00.000Z| c3@somedomain.com | {anything}|
          +----------------------------------------------------------------------------+
        TEXT

        page5_table = <<-TEXT
          +-----------------------------------------------------------------------------+
          | users.first_name |   users.member_since    |    users.email     | users.id  |
          +-----------------------------------------------------------------------------+
          |        C         | 2023-04-01T01:02:00.000Z| c2@somedomain.com  | {anything}|
          |        D         | 2022-11-01T00:19:00.000Z| d13@somedomain.com | {anything}|
          +-----------------------------------------------------------------------------+
        TEXT

        page6_table = <<-TEXT
          +-----------------------------------------------------------------------------+
          | users.first_name |   users.member_since    |    users.email     | users.id  |
          +-----------------------------------------------------------------------------+
          |        D         | 2021-12-31T18:09:00.000Z| d12@somedomain.com | {anything}|
          +-----------------------------------------------------------------------------+
        TEXT

        page1 = page
        page2 = page1.next
        page3 = page2.next
        page4 = page3.next
        page5 = page4.next
        page6 = page5.next

        expect(page1.as_table).to match_table(page1_table)
        expect(page2.as_table).to match_table(page2_table)
        expect(page3.as_table).to match_table(page3_table)
        expect(page4.as_table).to match_table(page4_table)
        expect(page5.as_table).to match_table(page5_table)
        expect(page6.as_table).to match_table(page6_table)

        expect(page2.prev.as_table).to match_table(page1_table)
        expect(page3.prev.as_table).to match_table(page2_table)
        expect(page4.prev.as_table).to match_table(page3_table)
        expect(page5.prev.as_table).to match_table(page4_table)
        expect(page6.prev.as_table).to match_table(page5_table)
      end
    end

    context 'with date values' do
      before do
        User.create(email: 'a@somedomain.com', first_name: 'A', birth_date: '1989-01-06')
        User.create(email: 'b@somedomain.com', first_name: 'B')
        User.create(email: 'ab@somedomain.com', first_name: 'A', birth_date: '1990-09-20')
        User.create(email: 'ac@somedomain.com', first_name: 'A', birth_date: '1991-02-02')
        User.create(email: 'ab2@somedomain.com', first_name: 'B')
        User.create(email: 'ab3@somedomain.com', first_name: 'B', birth_date: '1969-07-01')
        User.create(email: 'c3@somedomain.com', first_name: 'C', birth_date: '1975-08-10')
        User.create(email: 'c2@somedomain.com', first_name: 'C', birth_date: '1990-09-19')
        User.create(email: 'c1@somedomain.com', first_name: 'C')
        User.create(email: 'd13@somedomain.com', first_name: 'D', birth_date: '1991-02-01')
        User.create(email: 'd12@somedomain.com', first_name: 'D', birth_date: '1990-09-20')
      end

      subject(:page) do
        described_class.new(
          User.where("email like '%@somedomain.com'"),
          order: {
            birth_date: { direction: :asc, nulls: :first },
            first_name: { direction: :asc },
            email: { direction: :desc }
          },
          limit: 2
        )
      end

      it 'correctly paginates the records' do
        page1_table = <<-TEXT
          +----------------------------------------------------------------------+
          | users.birth_date | users.first_name |    users.email     | users.id  |
          +----------------------------------------------------------------------+
          |      <NULL>      |        B         |  b@somedomain.com  |{anything} |
          |      <NULL>      |        B         | ab2@somedomain.com |{anything} |
          +----------------------------------------------------------------------+
        TEXT

        page2_table = <<-TEXT
          +----------------------------------------------------------------------+
          | users.birth_date | users.first_name |    users.email     | users.id  |
          +----------------------------------------------------------------------+
          |      <NULL>      |        C         | c1@somedomain.com  |{anything} |
          |    1969-07-01    |        B         | ab3@somedomain.com |{anything} |
          +----------------------------------------------------------------------+
        TEXT

        page3_table = <<-TEXT
          +---------------------------------------------------------------------+
          | users.birth_date | users.first_name |    users.email    | users.id  |
          +---------------------------------------------------------------------+
          |    1975-08-10    |        C         | c3@somedomain.com |{anything} |
          |    1989-01-06    |        A         | a@somedomain.com  |{anything} |
          +---------------------------------------------------------------------+
        TEXT

        page4_table = <<-TEXT
          +---------------------------------------------------------------------+
          | users.birth_date | users.first_name |    users.email    | users.id  |
          +---------------------------------------------------------------------+
          |    1990-09-19    |        C         | c2@somedomain.com |{anything} |
          |    1990-09-20    |        A         | ab@somedomain.com |{anything} |
          +---------------------------------------------------------------------+
        TEXT

        page5_table = <<-TEXT
          +----------------------------------------------------------------------+
          | users.birth_date | users.first_name |    users.email     | users.id  |
          +----------------------------------------------------------------------+
          |    1990-09-20    |        D         | d12@somedomain.com |{anything} |
          |    1991-02-01    |        D         | d13@somedomain.com |{anything} |
          +----------------------------------------------------------------------+
        TEXT

        page6_table = <<-TEXT
          +---------------------------------------------------------------------+
          | users.birth_date | users.first_name |    users.email    | users.id  |
          +---------------------------------------------------------------------+
          |    1991-02-02    |        A         | ac@somedomain.com |{anything} |
          +---------------------------------------------------------------------+
        TEXT

        page1 = page
        page2 = page1.next
        page3 = page2.next
        page4 = page3.next
        page5 = page4.next
        page6 = page5.next

        expect(page1.as_table).to match_table(page1_table)
        expect(page2.as_table).to match_table(page2_table)
        expect(page3.as_table).to match_table(page3_table)
        expect(page4.as_table).to match_table(page4_table)
        expect(page5.as_table).to match_table(page5_table)
        expect(page6.as_table).to match_table(page6_table)

        expect(page2.prev.as_table).to match_table(page1_table)
        expect(page3.prev.as_table).to match_table(page2_table)
        expect(page4.prev.as_table).to match_table(page3_table)
        expect(page5.prev.as_table).to match_table(page4_table)
        expect(page6.prev.as_table).to match_table(page5_table)
      end
    end

    context 'with boolean values' do
      before do
        User.create(email: 'a@somedomain.com', first_name: 'A', active: true)
        User.create(email: 'b@somedomain.com', first_name: 'B')
        User.create(email: 'ab@somedomain.com', first_name: 'A', active: true)
        User.create(email: 'ac@somedomain.com', first_name: 'A', active: false)
        User.create(email: 'ab2@somedomain.com', first_name: 'B')
        User.create(email: 'ab3@somedomain.com', first_name: 'B', active: true)
        User.create(email: 'c3@somedomain.com', first_name: 'C', active: false)
        User.create(email: 'c2@somedomain.com', first_name: 'C', active: false)
        User.create(email: 'c1@somedomain.com', first_name: 'C', active: true)
        User.create(email: 'd13@somedomain.com', first_name: 'D')
        User.create(email: 'd12@somedomain.com', first_name: 'D', active: true)
      end

      subject(:page) do
        described_class.new(
          User.where("email like '%@somedomain.com'"),
          order: {
            active: { direction: :asc, nulls: :first },
            first_name: { direction: :desc },
            email: { direction: :asc }
          },
          limit: 2
        )
      end

      it 'correctly paginates the records' do
        page1_table = <<-TEXT
          +------------------------------------------------------------------+
          | users.active | users.first_name |    users.email     | users.id  |
          +------------------------------------------------------------------+
          |    <NULL>    |        D         | d13@somedomain.com |{anything} |
          |    <NULL>    |        B         | ab2@somedomain.com |{anything} |
          +------------------------------------------------------------------+
        TEXT

        page2_table = <<-TEXT
          +-----------------------------------------------------------------+
          | users.active | users.first_name |    users.email    | users.id  |
          +-----------------------------------------------------------------+
          |    <NULL>    |        B         | b@somedomain.com  |{anything} |
          |   {false}    |        C         | c2@somedomain.com |{anything} |
          +-----------------------------------------------------------------+
        TEXT

        page3_table = <<-TEXT
          +-----------------------------------------------------------------+
          | users.active | users.first_name |    users.email    | users.id  |
          +-----------------------------------------------------------------+
          |   {false}    |        C         | c3@somedomain.com |{anything} |
          |   {false}    |        A         | ac@somedomain.com |{anything} |
          +-----------------------------------------------------------------+
        TEXT

        page4_table = <<-TEXT
          +------------------------------------------------------------------+
          | users.active | users.first_name |    users.email     | users.id  |
          +------------------------------------------------------------------+
          |    {true}    |        D         | d12@somedomain.com |{anything} |
          |    {true}    |        C         | c1@somedomain.com  |{anything} |
          +------------------------------------------------------------------+
        TEXT

        page5_table = <<-TEXT
          +------------------------------------------------------------------+
          | users.active | users.first_name |    users.email     | users.id  |
          +------------------------------------------------------------------+
          |    {true}    |        B         | ab3@somedomain.com |{anything} |
          |    {true}    |        A         |  a@somedomain.com  |{anything} |
          +------------------------------------------------------------------+
        TEXT

        page6_table = <<-TEXT
          +-----------------------------------------------------------------+
          | users.active | users.first_name |    users.email    | users.id  |
          +-----------------------------------------------------------------+
          |    {true}    |        A         | ab@somedomain.com |{anything} |
          +-----------------------------------------------------------------+
        TEXT

        page1 = page
        page2 = page1.next
        page3 = page2.next
        page4 = page3.next
        page5 = page4.next
        page6 = page5.next

        expect(page1.as_table).to match_table(page1_table)
        expect(page2.as_table).to match_table(page2_table)
        expect(page3.as_table).to match_table(page3_table)
        expect(page4.as_table).to match_table(page4_table)
        expect(page5.as_table).to match_table(page5_table)
        expect(page6.as_table).to match_table(page6_table)

        expect(page2.prev.as_table).to match_table(page1_table)
        expect(page3.prev.as_table).to match_table(page2_table)
        expect(page4.prev.as_table).to match_table(page3_table)
        expect(page5.prev.as_table).to match_table(page4_table)
        expect(page6.prev.as_table).to match_table(page5_table)
      end
    end

    context 'with float values' do
      before do
        User.create(email: 'a@somedomain.com', first_name: 'A', stats: 2)
        User.create(email: 'b@somedomain.com', first_name: 'B')
        User.create(email: 'ab@somedomain.com', first_name: 'A', stats: 0)
        User.create(email: 'ac@somedomain.com', first_name: 'A', stats: 1)
        User.create(email: 'ab2@somedomain.com', first_name: 'B', stats: 1)
        User.create(email: 'ab3@somedomain.com', first_name: 'B', stats: 3)
        User.create(email: 'c3@somedomain.com', first_name: 'C', stats: 3.5)
        User.create(email: 'c2@somedomain.com', first_name: 'C', stats: 2.4)
        User.create(email: 'c1@somedomain.com', first_name: 'C', stats: -2)
        User.create(email: 'd13@somedomain.com', first_name: 'D', stats: -118392)
        User.create(email: 'd12@somedomain.com', first_name: 'D', stats: 12.14)
      end

      subject(:page) do
        described_class.new(
          User.where("email like '%@somedomain.com'"),
          order: {
            stats: { direction: :desc, nulls: :last },
            first_name: { direction: :desc },
            email: { direction: :asc }
          },
          limit: 2
        )
      end

      it 'correctly paginates the records' do
        page1_table = <<-TEXT
          +-----------------------------------------------------------------+
          | users.stats | users.first_name |    users.email     | users.id  |
          +-----------------------------------------------------------------+
          |    12.14    |        D         | d12@somedomain.com | {anything}|
          |     3.5     |        C         | c3@somedomain.com  | {anything}|
          +-----------------------------------------------------------------+
        TEXT

        page2_table = <<-TEXT
          +-----------------------------------------------------------------+
          | users.stats | users.first_name |    users.email     | users.id  |
          +-----------------------------------------------------------------+
          |      3      |        B         | ab3@somedomain.com | {anything}|
          |     2.4     |        C         | c2@somedomain.com  | {anything}|
          +-----------------------------------------------------------------+
        TEXT

        page3_table = <<-TEXT
          +-----------------------------------------------------------------+
          | users.stats | users.first_name |    users.email     | users.id  |
          +-----------------------------------------------------------------+
          |      2      |        A         |  a@somedomain.com  | {anything}|
          |      1      |        B         | ab2@somedomain.com | {anything}|
          +-----------------------------------------------------------------+
        TEXT

        page4_table = <<-TEXT
          +----------------------------------------------------------------+
          | users.stats | users.first_name |    users.email    | users.id  |
          +----------------------------------------------------------------+
          |      1      |        A         | ac@somedomain.com | {anything}|
          |      0      |        A         | ab@somedomain.com | {anything}|
          +----------------------------------------------------------------+
        TEXT

        page5_table = <<-TEXT
          +-----------------------------------------------------------------+
          | users.stats | users.first_name |    users.email     | users.id  |
          +-----------------------------------------------------------------+
          |     -2      |        C         | c1@somedomain.com  | {anything}|
          |   -118392   |        D         | d13@somedomain.com | {anything}|
          +-----------------------------------------------------------------+
        TEXT

        page6_table = <<-TEXT
          +---------------------------------------------------------------+
          | users.stats | users.first_name |   users.email    | users.id  |
          +---------------------------------------------------------------+
          |   <NULL>    |        B         | b@somedomain.com | {anything}|
          +---------------------------------------------------------------+
        TEXT

        page1 = page
        page2 = page1.next
        page3 = page2.next
        page4 = page3.next
        page5 = page4.next
        page6 = page5.next

        expect(page1.as_table).to match_table(page1_table)
        expect(page2.as_table).to match_table(page2_table)
        expect(page3.as_table).to match_table(page3_table)
        expect(page4.as_table).to match_table(page4_table)
        expect(page5.as_table).to match_table(page5_table)
        expect(page6.as_table).to match_table(page6_table)

        expect(page2.prev.as_table).to match_table(page1_table)
        expect(page3.prev.as_table).to match_table(page2_table)
        expect(page4.prev.as_table).to match_table(page3_table)
        expect(page5.prev.as_table).to match_table(page4_table)
        expect(page6.prev.as_table).to match_table(page5_table)
      end
    end

    context 'with decimal values' do
      before do
        User.create(email: 'a@somedomain.com', first_name: 'C', balance: BigDecimal('-123921349440.03'))
        User.create(email: 'b@somedomain.com', first_name: 'B', balance: BigDecimal('8294912740.01928'))
        User.create(email: 'ab@somedomain.com', first_name: 'A')
        User.create(email: 'ac@somedomain.com', first_name: 'A', balance: BigDecimal('53.0'))
        User.create(email: 'ab2@somedomain.com', first_name: 'B', balance: BigDecimal('70'))
        User.create(email: 'ab3@somedomain.com', first_name: 'B', balance: BigDecimal('-0.000000052'))
        User.create(email: 'c3@somedomain.com', first_name: 'A', balance: BigDecimal('-123921349440.02'))
        User.create(email: 'c2@somedomain.com', first_name: 'C', balance: BigDecimal('0.00135'))
        User.create(email: 'c1@somedomain.com', first_name: 'C', balance: BigDecimal('0.00135'))
        User.create(email: 'd13@somedomain.com', first_name: 'D', balance: BigDecimal('53'))
        User.create(email: 'd12@somedomain.com', first_name: 'D', balance: BigDecimal('11'))
      end

      subject(:page) do
        described_class.new(
          User.where("email like '%@somedomain.com'"),
          order: {
            balance: { direction: :asc, nulls: :first },
            first_name: { direction: :asc },
            email: { direction: :asc },
            id: { direction: :asc }
          },
          limit: 2
        )
      end

      it 'correctly paginates the records' do
        page1_table = <<-TEXT
          +-------------------------------------------------------------------------+
          |   users.balance      | users.first_name |    users.email    | users.id  |
          +-------------------------------------------------------------------------+
          |      <NULL>          |        A         | ab@somedomain.com |{anything} |
          | -123921349440.03     |        C         | a@somedomain.com  |{anything} |
          +-------------------------------------------------------------------------+
        TEXT

        page2_table = <<-TEXT
          +--------------------------------------------------------------------------+
          |  users.balance       | users.first_name |    users.email     | users.id  |
          +--------------------------------------------------------------------------+
          | -123921349440.02     |        A         | c3@somedomain.com  | {anything}|
          |   -0.000000052       |        B         | ab3@somedomain.com | {anything}|
          +--------------------------------------------------------------------------+
        TEXT

        page3_table = <<-TEXT
          +------------------------------------------------------------------+
          | users.balance | users.first_name |    users.email    | users.id  |
          +------------------------------------------------------------------+
          |    0.00135    |        C         | c1@somedomain.com | {anything}|
          |    0.00135    |        C         | c2@somedomain.com | {anything}|
          +------------------------------------------------------------------+
        TEXT

        page4_table = <<-TEXT
          +-------------------------------------------------------------------+
          | users.balance | users.first_name |    users.email     | users.id  |
          +-------------------------------------------------------------------+
          |      11        |        D         | d12@somedomain.com | {anything}|
          |      53        |        A         | ac@somedomain.com  | {anything}|
          +-------------------------------------------------------------------+
        TEXT

        page5_table = <<-TEXT
          +-------------------------------------------------------------------+
          | users.balance | users.first_name |    users.email     | users.id  |
          +-------------------------------------------------------------------+
          |     53        |        D         | d13@somedomain.com | {anything}|
          |     70        |        B         | ab2@somedomain.com | {anything}|
          +-------------------------------------------------------------------+
        TEXT

        page6_table = <<-TEXT
          +--------------------------------------------------------------------+
          |   users.balance  | users.first_name |   users.email    | users.id  |
          +--------------------------------------------------------------------+
          | 8294912740.01928 |        B         | b@somedomain.com | {anything}|
          +--------------------------------------------------------------------+
        TEXT

        page1 = page
        page2 = page1.next
        page3 = page2.next
        page4 = page3.next
        page5 = page4.next
        page6 = page5.next

        expect(page1.as_table).to match_table(page1_table)
        expect(page2.as_table).to match_table(page2_table)
        expect(page3.as_table).to match_table(page3_table)
        expect(page4.as_table).to match_table(page4_table)
        expect(page5.as_table).to match_table(page5_table)
        expect(page6.as_table).to match_table(page6_table)

        expect(page2.prev.as_table).to match_table(page1_table)
        expect(page3.prev.as_table).to match_table(page2_table)
        expect(page4.prev.as_table).to match_table(page3_table)
        expect(page5.prev.as_table).to match_table(page4_table)
        expect(page6.prev.as_table).to match_table(page5_table)
      end
    end

    context 'with bigint values' do
      before do
        User.create(email: 'a@somedomain.com', first_name: 'C', score: 5122147483648)
        User.create(email: 'b@somedomain.com', first_name: 'B', score: 64)
        User.create(email: 'ab@somedomain.com', first_name: 'A')
        User.create(email: 'ac@somedomain.com', first_name: 'A', score: 0)
        User.create(email: 'ab2@somedomain.com', first_name: 'B', score: 64)
        User.create(email: 'ab3@somedomain.com', first_name: 'B', score: 64)
        User.create(email: 'c3@somedomain.com', first_name: 'A')
        User.create(email: 'c2@somedomain.com', first_name: 'C', score: -98172345345019340)
        User.create(email: 'c1@somedomain.com', first_name: 'C', score: 5122147483648)
        User.create(email: 'd13@somedomain.com', first_name: 'D', score: -10)
        User.create(email: 'd12@somedomain.com', first_name: 'D', score: 13)
      end

      subject(:page) do
        described_class.new(
          User.where("email like '%@somedomain.com'"),
          order: {
            score: { direction: :desc, nulls: :first },
            first_name: { direction: :asc },
            email: { direction: :asc },
            id: { direction: :asc }
          },
          limit: 2
        )
      end

      it 'correctly paginates the records' do
        page1_table = <<-TEXT
          +----------------------------------------------------------------+
          | users.score | users.first_name |    users.email    | users.id  |
          +----------------------------------------------------------------+
          |   <NULL>    |        A         | ab@somedomain.com |{anything} |
          |   <NULL>    |        A         | c3@somedomain.com |{anything} |
          +----------------------------------------------------------------+
        TEXT

        page2_table = <<-TEXT
          +------------------------------------------------------------------+
          |  users.score  | users.first_name |    users.email    | users.id  |
          +------------------------------------------------------------------+
          | 5122147483648 |        C         | a@somedomain.com  |{anything} |
          | 5122147483648 |        C         | c1@somedomain.com |{anything} |
          +------------------------------------------------------------------+
        TEXT

        page3_table = <<-TEXT
          +-----------------------------------------------------------------+
          | users.score | users.first_name |    users.email     | users.id  |
          +-----------------------------------------------------------------+
          |     64      |        B         | ab2@somedomain.com |{anything} |
          |     64      |        B         | ab3@somedomain.com |{anything} |
          +-----------------------------------------------------------------+
        TEXT

        page4_table = <<-TEXT
          +-----------------------------------------------------------------+
          | users.score | users.first_name |    users.email     | users.id  |
          +-----------------------------------------------------------------+
          |     64      |        B         |  b@somedomain.com  |{anything} |
          |     13      |        D         | d12@somedomain.com |{anything} |
          +-----------------------------------------------------------------+
        TEXT

        page5_table = <<-TEXT
          +-----------------------------------------------------------------+
          | users.score | users.first_name |    users.email     | users.id  |
          +-----------------------------------------------------------------+
          |      0      |        A         | ac@somedomain.com  |{anything} |
          |     -10     |        D         | d13@somedomain.com |{anything} |
          +-----------------------------------------------------------------+
        TEXT

        page6_table = <<-TEXT
          +-----------------------------------------------------------------------+
          |    users.score     | users.first_name |    users.email    | users.id  |
          +-----------------------------------------------------------------------+
          | -98172345345019340 |        C         | c2@somedomain.com |{anything} |
          +-----------------------------------------------------------------------+
        TEXT

        page1 = page
        page2 = page1.next
        page3 = page2.next
        page4 = page3.next
        page5 = page4.next
        page6 = page5.next

        expect(page1.as_table).to match_table(page1_table)
        expect(page2.as_table).to match_table(page2_table)
        expect(page3.as_table).to match_table(page3_table)
        expect(page4.as_table).to match_table(page4_table)
        expect(page5.as_table).to match_table(page5_table)
        expect(page6.as_table).to match_table(page6_table)

        expect(page2.prev.as_table).to match_table(page1_table)
        expect(page3.prev.as_table).to match_table(page2_table)
        expect(page4.prev.as_table).to match_table(page3_table)
        expect(page5.prev.as_table).to match_table(page4_table)
        expect(page6.prev.as_table).to match_table(page5_table)
      end
    end
  end

  context 'with custom Cursor implementation' do
    before do
      allow(Rotulus.configuration).to receive_messages(cursor_class: custom_cursor_class)
    end

    let(:custom_cursor_class) do
      Class.new(Rotulus::Cursor) do
        def self.storage
          @storage ||= {}
        end

        def self.decode(token)
          storage[token]
        end

        def self.encode(data)
          storage_key = "customtoken-#{SecureRandom.uuid}"
          storage[storage_key] = data
          storage_key
        end
      end
    end

    let(:page) do
      described_class.new(
        User.all,
        order: {
          last_name: { direction: :desc, nulls: :first },
          email: { direction: :asc }
        },
        limit: 5
      )
    end

    it 'uses the custom Cursor implementation' do
      expect(page.next_token).to start_with('customtoken-')
      expect(page.next.prev_token).to start_with('customtoken-')
    end

    it 'paginates correctly' do
      page1_table = <<-TEXT
        +------------------------------------------------------+
        | users.last_name |      users.email       | users.id  |
        +------------------------------------------------------+
        |     <NULL>      |   george@domain.com    |{anything} |
        |     <NULL>      |    paul@domain.com     |{anything} |
        |     <NULL>      |    ringo@domain.com    |{anything} |
        |      Smith      | jane.c.smith@email.com |{anything} |
        |     Record      |   excluded@email.com   |{anything} |
        +------------------------------------------------------+
      TEXT

      page2_table = <<-TEXT
        +--------------------------------------------------------+
        | users.last_name |       users.email        | users.id  |
        +--------------------------------------------------------+
        |    Gallagher    | rory.gallagher@email.com |{anything} |
        |       Doe       |    jane.doe@email.com    |{anything} |
        |       Doe       |    john.doe@email.com    |{anything} |
        |      Apple      |  johnny.apple@email.com  |{anything} |
        +--------------------------------------------------------+
      TEXT

      page1 = page
      page2 = page1.next

      expect(page1.as_table).to match_table(page1_table)
      expect(page2.as_table).to match_table(page2_table)

      expect(page2.prev.as_table).to match_table(page1_table)
    end
  end
end
