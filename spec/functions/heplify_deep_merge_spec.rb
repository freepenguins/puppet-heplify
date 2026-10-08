# frozen_string_literal: true

require 'spec_helper'

describe 'heplify::deep_merge' do
  it { is_expected.to run.with_params({ 'a' => { 'b' => 1, 'c' => 2 } }, { 'a' => { 'b' => 3 } }).and_return({ 'a' => { 'b' => 3, 'c' => 2 } }) }
  it { is_expected.to run.with_params({ 'keep' => true }, { 'new' => 'x' }).and_return({ 'keep' => true, 'new' => 'x' }) }
  it { is_expected.to run.with_params({ 'list' => [1, 2] }, { 'list' => [3] }).and_return({ 'list' => [3] }) }
  it { is_expected.to run.with_params({ 'a' => 1 }, { 'a' => { 'b' => 1 } }).and_return({ 'a' => { 'b' => 1 } }) }
  it { is_expected.to run.with_params({}, {}).and_return({}) }
  it { is_expected.to run.with_params('not a hash', {}).and_raise_error(ArgumentError) }
end
