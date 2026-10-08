# frozen_string_literal: true

require 'spec_helper'

describe 'heplify::release_arch' do
  it { is_expected.to run.with_params('x86_64', 'heplify').and_return('amd64') }
  it { is_expected.to run.with_params('amd64', 'heplify').and_return('amd64') }
  it { is_expected.to run.with_params('aarch64', 'heplify').and_return('arm64') }
  it { is_expected.to run.with_params('arm64', 'heplify').and_return('arm64') }
  it { is_expected.to run.with_params('ppc64le', 'heplify::server').and_raise_error(%r{heplify::server: no release binary for architecture ppc64le}) }
end
