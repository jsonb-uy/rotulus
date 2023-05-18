require 'spec_helper'

describe Rotulus::PageTableizer do
  subject(:tableizer) { described_class.new(page) }

  let(:page) do
    Rotulus::Page.new(
      User.all,
      order: {
        first_name: { direction: :desc },
        last_name: { direction: :asc },
        email: { direction: :asc }
      },
      limit: 2
    )
  end

  describe '#tableize' do
    context 'when page has records' do
      before do
        User.create(email: 'john.doe@email.com', first_name: 'John', last_name: 'Doe')
        User.create(email: 'jane.doe@email.com', first_name: 'Jane', last_name: 'Doe')
        User.create(email: 'jane.c.smith@email.com', first_name: 'Jane', last_name: 'Smith')
      end

      it 'returns a string showing the page records in table format' do
        table = <<-TEXT
          +-------------------------------------------------------------------------------------+
          |   users.first_name   |   users.last_name   |      users.email       |   users.id    |
          +-------------------------------------------------------------------------------------+
          |         John         |         Doe         |   john.doe@email.com   |   {anything}  |
          |         Jane         |         Doe         |   jane.doe@email.com   |   {anything}  |
          +-------------------------------------------------------------------------------------+
        TEXT

        expect(tableizer.tableize).to be_a(String)
        expect(tableizer.tableize).to match_table(table)
      end
    end
  end

  context 'when page has no records' do
    it 'returns an empty string' do
      expect(tableizer.tableize).to eql('')
    end
  end
end
