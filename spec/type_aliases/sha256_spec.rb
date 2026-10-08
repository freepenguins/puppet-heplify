# frozen_string_literal: true

require 'spec_helper'

describe 'Heplify::Sha256' do
  it { is_expected.to allow_value('c91927c793248f153bd07725a39b94145ef893a364d3029e64f4e1f9769a2faa') }
  it { is_expected.not_to allow_value('C91927C793248F153BD07725A39B94145EF893A364D3029E64F4E1F9769A2FAA') }
  it { is_expected.not_to allow_value('c91927c7') }
  it { is_expected.not_to allow_value(nil) }
end
