require 'spec_helper'

describe Rotulus::Configuration do
  subject(:config) { described_class.new }

  describe '#page_default_limit' do
    it 'returns 5 by default' do
      expect(config.page_default_limit).to be(5)
    end

    context 'with non-positive numeric configured value' do
      context 'when :page_max_limit is less than 5' do
        it 'returns the :page_max_limit value' do
          config.page_default_limit = -1
          config.page_max_limit = 3

          expect(config.page_default_limit).to be(3)
        end
      end

      it 'returns 5 by default' do
        config.page_default_limit = 0
        expect(config.page_default_limit).to be(5)

        config.page_default_limit = -1
        expect(config.page_default_limit).to be(5)
      end
    end

    context 'with configured value greater than the :page_max_limit' do
      it 'returns the :page_max_limit value' do
        config.page_max_limit = 3
        config.page_default_limit = 5

        expect(config.page_default_limit).to be(3)
      end
    end
  end

  describe '#page_default_limit=' do
    it 'sets the default record limit per page' do
      config.page_default_limit = 15

      expect(config.page_default_limit).to be(15)
    end
  end

  describe '#page_max_limit' do
    it 'returns 50 by default' do
      expect(config.page_max_limit).to be(50)
    end

    context 'with non-positive numeric configured value' do
      it 'returns 50 by default' do
        config.page_max_limit = 0
        expect(config.page_max_limit).to be(50)

        config.page_max_limit = -1
        expect(config.page_max_limit).to be(50)
      end
    end
  end

  describe '#page_max_limit=' do
    it 'sets the default record limit per page' do
      config.page_max_limit = 50

      expect(config.page_max_limit).to be(50)
    end
  end

  describe '#secret' do
    around do |example|
      orig_value = ENV['ROTULUS_SECRET']
      ENV['ROTULUS_SECRET'] = 'somevaluehere'

      example.call

      ENV['ROTULUS_SECRET'] = orig_value
    end

    it 'returns the environment variable `ROTULUS_SECRET` value by default' do
      expect(config.secret).to eql('somevaluehere')
    end
  end

  describe '#secret=' do
    it 'sets the secret used in generating Cursor state' do
      config.secret = 'customvalue'

      expect(config.secret).to eql('customvalue')
    end
  end

  describe '#token_expires_in' do
    it 'returns 3 days(in seconds) by default' do
      expect(config.token_expires_in).to eql(3.days.seconds.to_i)
    end

    context 'with non-positive numeric configured value' do
      it 'returns nil by default' do
        config.token_expires_in = 0
        expect(config.token_expires_in).to be_nil

        config.token_expires_in = -1
        expect(config.token_expires_in).to be_nil
      end
    end
  end

  describe '#token_expires_in=' do
    it 'sets the default token expiration in seconds' do
      config.token_expires_in = 360

      expect(config.token_expires_in).to be(360)
    end
  end

  describe '#cursor_class' do
    it "returns 'Rotulus::Cursor' class by default" do
      expect(config.cursor_class).to eql(Rotulus::Cursor)
    end
  end

  describe '#cursor_class=' do
    it 'sets the Cursor implementation to be used' do
      custom_clazz = Class.new(Rotulus::Cursor)

      config.cursor_class = custom_clazz

      expect(config.cursor_class).to eql(custom_clazz)
    end
  end
end
