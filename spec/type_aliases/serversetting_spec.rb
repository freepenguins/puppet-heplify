# frozen_string_literal: true

require 'spec_helper'

describe 'Heplify::ServerSetting' do
  it { is_expected.to allow_value('0.0.0.0:9060') }
  it { is_expected.to allow_value(14) }
  it { is_expected.to allow_value(true) }
  it { is_expected.to allow_value(['OPTIONS', 'NOTIFY']) }
  it { is_expected.to allow_value([1, 5, 100]) }
  it { is_expected.not_to allow_value({ 'nested' => 'hash' }) }
end
