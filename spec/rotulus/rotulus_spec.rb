require 'spec_helper'

describe Rotulus do
  describe '.configuration' do
    it 'returns a configuration singleton' do
      expect(Rotulus.configuration).to be_a(Rotulus::Configuration)
      expect(Rotulus.configuration).to be(Rotulus.configuration)
    end
  end

  describe '.configure' do
    it 'yields a configuration singleton' do
      Rotulus.configure do |config|
        expect(config).to be_a(Rotulus::Configuration)
      end
    end
  end

  describe '.db' do
    before { Rotulus.instance_variable_set(:@db, nil) }

    context 'when using mysql' do
      before { allow(ActiveRecord::Base.connection).to receive(:adapter_name) { 'mysql' } }

      it 'returns mysql DB instance' do
        expect(Rotulus.db).to be_a(Rotulus::DB::MySQL)
      end
    end

    context 'when using mysql2' do
      before { allow(ActiveRecord::Base.connection).to receive(:adapter_name) { 'mysql2' } }

      it 'returns mysql DB instance' do
        expect(Rotulus.db).to be_a(Rotulus::DB::MySQL)
      end
    end

    context 'when using postgresql' do
      before { allow(ActiveRecord::Base.connection).to receive(:adapter_name) { 'postgresql' } }

      it 'returns postgresql DB instance' do
        expect(Rotulus.db).to be_a(Rotulus::DB::PostgreSQL)
      end
    end

    context 'when using sqlite' do
      before { allow(ActiveRecord::Base.connection).to receive(:adapter_name) { 'sqlite' } }

      it 'returns sqlite DB instance' do
        expect(Rotulus.db).to be_a(Rotulus::DB::SQLite)
      end
    end
  end
end
