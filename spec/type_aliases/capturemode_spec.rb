# frozen_string_literal: true

require 'spec_helper'

describe 'Heplify::CaptureMode' do
  ['SIP', 'RTCP', 'RTP', 'DNS', 'LOG', 'DIAMETER'].each do |mode|
    it { is_expected.to allow_value(mode) }
  end

  it { is_expected.not_to allow_value('sip') }
  it { is_expected.not_to allow_value('SIPRTCP') }
end
