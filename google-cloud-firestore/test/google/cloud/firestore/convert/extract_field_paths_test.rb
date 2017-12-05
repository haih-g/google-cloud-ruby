# Copyright 2017, Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "helper"

describe Google::Cloud::Firestore::Convert, :extract_field_paths do
  # These tests are a sanity check on the implementation of the conversion methods.
  # These tests are testing private methods and this is generally not a great idea.
  # But these conversions are so important that it was decided to do it anyway.

  it "extracts field paths" do
    orig = { "foo.bar" => "BAZ" }

    hash, paths = Google::Cloud::Firestore::Convert.extract_field_paths orig
    hash.must_equal({ "foo" => { "bar" => "BAZ" } })
    paths.must_equal ["foo.bar"]
  end

  it "extracts only top-level field paths" do
    orig = { "foo.bar" => { "baz.bif" => 42 } }

    hash, paths = Google::Cloud::Firestore::Convert.extract_field_paths orig
    hash.must_equal({ "foo" => { "bar" => { "baz.bif" => 42 } } })
    paths.must_equal ["foo.bar"]
  end

  it "handles an empty hash" do
    orig = {}

    hash, paths = Google::Cloud::Firestore::Convert.extract_field_paths orig
    hash.must_equal({})
    paths.must_equal []
  end
end