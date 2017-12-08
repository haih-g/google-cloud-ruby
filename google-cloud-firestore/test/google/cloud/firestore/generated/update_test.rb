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

describe "Cross-Language Update Tests", :mock_firestore do
  let(:document_path) { "C/d" }
  let(:database_path) { "projects/#{project}/databases/(default)" }
  let(:documents_path) { "#{database_path}/documents" }

  let(:commit_time) { Time.now }
  let :commit_resp do
    Google::Firestore::V1beta1::CommitResponse.new(
      commit_time: Google::Cloud::Firestore::Convert.time_to_timestamp(commit_time),
      write_results: [Google::Firestore::V1beta1::WriteResult.new(
        update_time: Google::Cloud::Firestore::Convert.time_to_timestamp(commit_time))]
      )
  end

  it "basic" do
    update_json = "{\"a\": 1}"
    update_data = JSON.parse update_json

    update_writes = [
      Google::Firestore::V1beta1::Write.new(
        update: Google::Firestore::V1beta1::Document.new(
          name: "projects/projectID/databases/(default)/documents/C/d",
          fields: {
            "a" => Google::Firestore::V1beta1::Value.new(integer_value: 1)
          }
        ),
        update_mask: Google::Firestore::V1beta1::DocumentMask.new(
          field_paths: ["a"]
        ),
        current_document: Google::Firestore::V1beta1::Precondition.new(
          exists: true)
      )
    ]

    firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

    firestore.update document_path, update_data
  end

  it "complex" do
    update_json = "{\"a\": [1, 2.5], \"b\": {\"c\": [\"three\", {\"d\": true}]}}"
    update_data = JSON.parse update_json

    update_writes = [
      Google::Firestore::V1beta1::Write.new(
        update: Google::Firestore::V1beta1::Document.new(
          name: "projects/projectID/databases/(default)/documents/C/d",
          fields: {
            "a" => Google::Firestore::V1beta1::Value.new(array_value: Google::Firestore::V1beta1::ArrayValue.new(values: [
              Google::Firestore::V1beta1::Value.new(integer_value: 1),
              Google::Firestore::V1beta1::Value.new(double_value: 2.5)
            ])),
            "b" => Google::Firestore::V1beta1::Value.new(map_value: Google::Firestore::V1beta1::MapValue.new(fields: {
              "c" => Google::Firestore::V1beta1::Value.new(array_value: Google::Firestore::V1beta1::ArrayValue.new(values: [
                Google::Firestore::V1beta1::Value.new(string_value: "three"),
                Google::Firestore::V1beta1::Value.new(map_value: Google::Firestore::V1beta1::MapValue.new(fields: {
                  "d" => Google::Firestore::V1beta1::Value.new(boolean_value: true)
                }))
              ]))
            }))
          }
        ),
        update_mask: Google::Firestore::V1beta1::DocumentMask.new(
          field_paths: ["a", "b"]
        ),
        current_document: Google::Firestore::V1beta1::Precondition.new(
          exists: true)
      )
    ]

    firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

    firestore.update document_path, update_data
  end

  it "invalid character" do
    update_json = "{\"a~b\": 1}"
    update_data = JSON.parse update_json

    error = expect do
      firestore.update document_path, update_data
    end.must_raise ArgumentError
    error.message.must_equal "invalid character"
  end

  it "empty field path component" do

    update_json = "{\"a..b\": 1}"
    update_data = JSON.parse update_json

    error = expect do
      firestore.update document_path, update_data
    end.must_raise ArgumentError
    error.message.must_equal "empty paths not allowed"
  end

  it "no paths" do
    update_json = "{}"
    update_data = JSON.parse update_json

    error = expect do
      firestore.update document_path, update_data
    end.must_raise ArgumentError
    error.message.must_equal "data is required"
  end

  it "prefix #1" do
    update_json = "{\"a.b\": 1, \"a\": 2}"
    update_data = JSON.parse update_json

    error = expect do
      firestore.update document_path, update_data
    end.must_raise ArgumentError
    error.message.must_equal "one field cannot be a prefix of another"
  end

  it "prefix #2" do
    update_json = "{\"a\": 1, \"a.b\": 2}"
    update_data = JSON.parse update_json

    error = expect do
      firestore.update document_path, update_data
    end.must_raise ArgumentError
    error.message.must_equal "one field cannot be a prefix of another"
  end

  it "prefix #3" do
    update_json = "{\"a\": {\"b\": 1}, \"a.d\": 2}"
    update_data = JSON.parse update_json

    error = expect do
      firestore.update document_path, update_data
    end.must_raise ArgumentError
    error.message.must_equal "one field cannot be a prefix of another"
  end

  it "non-letter starting chars are quoted, except underscore" do
    update_json = "{\"_0.1.+2\": 1}"
    update_data = JSON.parse update_json

    update_writes = [
      Google::Firestore::V1beta1::Write.new(
        update: Google::Firestore::V1beta1::Document.new(
          name: "projects/projectID/databases/(default)/documents/C/d",
          fields: {
            "_0" => Google::Firestore::V1beta1::Value.new(map_value: Google::Firestore::V1beta1::MapValue.new(fields: {
              "1" => Google::Firestore::V1beta1::Value.new(map_value: Google::Firestore::V1beta1::MapValue.new(fields: {
                "+2" => Google::Firestore::V1beta1::Value.new(integer_value: 1)
              }))
            }))
          }
        ),
        update_mask: Google::Firestore::V1beta1::DocumentMask.new(
          field_paths: ["_0.`1`.`+2`"]
        ),
        current_document: Google::Firestore::V1beta1::Precondition.new(
          exists: true)
      )
    ]

    firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

    firestore.update document_path, update_data
  end

  it "Split on dots for top-level keys only" do
    update_json = "{\"h.g\": {\"j.k\": 6}}"
    update_data = JSON.parse update_json

    update_writes = [
      Google::Firestore::V1beta1::Write.new(
        update: Google::Firestore::V1beta1::Document.new(
          name: "projects/projectID/databases/(default)/documents/C/d",
          fields: {
            "h" => Google::Firestore::V1beta1::Value.new(map_value: Google::Firestore::V1beta1::MapValue.new(fields: {
              "g" => Google::Firestore::V1beta1::Value.new(map_value: Google::Firestore::V1beta1::MapValue.new(fields: {
                "j.k" => Google::Firestore::V1beta1::Value.new(integer_value: 6)
              }))
            }))
          }
        ),
        update_mask: Google::Firestore::V1beta1::DocumentMask.new(
          field_paths: ["h.g"]
        ),
        current_document: Google::Firestore::V1beta1::Precondition.new(
          exists: true)
      )
    ]

    firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

    firestore.update document_path, update_data
  end

  it "split on dots" do
    update_json = "{\"a.b.c\": 1}"
    update_data = JSON.parse update_json

    update_writes = [
      Google::Firestore::V1beta1::Write.new(
        update: Google::Firestore::V1beta1::Document.new(
          name: "projects/projectID/databases/(default)/documents/C/d",
          fields: {
            "a" => Google::Firestore::V1beta1::Value.new(map_value: Google::Firestore::V1beta1::MapValue.new(fields: {
              "b" => Google::Firestore::V1beta1::Value.new(map_value: Google::Firestore::V1beta1::MapValue.new(fields: {
                "c" => Google::Firestore::V1beta1::Value.new(integer_value: 1)
              }))
            }))
          }
        ),
        update_mask: Google::Firestore::V1beta1::DocumentMask.new(
          field_paths: ["a.b.c"]
        ),
        current_document: Google::Firestore::V1beta1::Precondition.new(
          exists: true)
      )
    ]

    firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

    firestore.update document_path, update_data
  end

  it "last-update-time precondition" do
    last_updated_at = Time.now - 42 #42 seconds ago

    update_json = "{\"a\": 1}"
    update_data = JSON.parse update_json

    update_writes = [
      Google::Firestore::V1beta1::Write.new(
        update: Google::Firestore::V1beta1::Document.new(
          name: "projects/projectID/databases/(default)/documents/C/d",
          fields: {
            "a" => Google::Firestore::V1beta1::Value.new(integer_value: 1)
          }
        ),
        update_mask: Google::Firestore::V1beta1::DocumentMask.new(
          field_paths: ["a"]
        ),
        current_document: Google::Firestore::V1beta1::Precondition.new(
          update_time: Google::Cloud::Firestore::Convert.time_to_timestamp(last_updated_at))
      )
    ]

    firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

    firestore.update document_path, update_data, update_time: last_updated_at
  end

  describe :DELETE do
    it "Delete" do
      update_data = { a: 1, b: :DELETE }

      update_writes = [
        Google::Firestore::V1beta1::Write.new(
          update: Google::Firestore::V1beta1::Document.new(
            name: "projects/projectID/databases/(default)/documents/C/d",
            fields: {
              "a" => Google::Firestore::V1beta1::Value.new(integer_value: 1)
            }
          ),
          update_mask: Google::Firestore::V1beta1::DocumentMask.new(
            field_paths: ["a", "b"]
          ),
          current_document: Google::Firestore::V1beta1::Precondition.new(
            exists: true)
        )
      ]

      firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

      firestore.update document_path, update_data
    end

    it "Delete alone" do
      update_data = { a: :DELETE }

      update_writes = [
        Google::Firestore::V1beta1::Write.new(
          update: Google::Firestore::V1beta1::Document.new(
            name: "projects/projectID/databases/(default)/documents/C/d"
          ),
          update_mask: Google::Firestore::V1beta1::DocumentMask.new(
            field_paths: ["a"]
          ),
          current_document: Google::Firestore::V1beta1::Precondition.new(
            exists: true)
        )
      ]

      firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

      firestore.update document_path, update_data
    end

    it "Delete with a dotted field" do
      update_data = { a: 1, "b.c": :DELETE, "b.d": 2 }

      update_writes = [
        Google::Firestore::V1beta1::Write.new(
          update: Google::Firestore::V1beta1::Document.new(
            name: "projects/projectID/databases/(default)/documents/C/d",
            fields: {
              "a" => Google::Firestore::V1beta1::Value.new(integer_value: 1),
              "b" => Google::Firestore::V1beta1::Value.new(map_value: Google::Firestore::V1beta1::MapValue.new(fields: {
                "d" => Google::Firestore::V1beta1::Value.new(integer_value: 2)
              }))
            }
          ),
          update_mask: Google::Firestore::V1beta1::DocumentMask.new(
            field_paths: ["a", "b.c", "b.d"]
          ),
          current_document: Google::Firestore::V1beta1::Precondition.new(
            exists: true)
        )
      ]

      firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

      firestore.update document_path, update_data
    end

    it "DELETE cannot be nested" do
      update_data = { a: { b: :DELETE } }

      error = expect do
        firestore.update document_path, update_data
      end.must_raise ArgumentError
      error.message.must_equal "DELETE cannot be nested"
    end

    it "DELETE cannot be anywhere inside an array value" do
      update_data = { a: [1, { b: :DELETE }] }

      error = expect do
        firestore.update document_path, update_data
      end.must_raise ArgumentError
      error.message.must_equal "cannot nest DELETE under arrays"
    end

    it "DELETE cannot be in an array value" do
      update_data = { a: [1, 2, :DELETE] }

      error = expect do
        firestore.update document_path, update_data
      end.must_raise ArgumentError
      error.message.must_equal "cannot nest DELETE under arrays"
    end
  end

  describe :SERVER_TIME do
    it "SERVER_TIME alone" do
      update_data = { a: :SERVER_TIME }

      update_writes = [
        Google::Firestore::V1beta1::Write.new(
          transform: Google::Firestore::V1beta1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1beta1::DocumentTransform::FieldTransform.new(
                field_path: "a",
                set_to_server_value: :REQUEST_TIME
              )
            ]
          ),
          current_document: Google::Firestore::V1beta1::Precondition.new(
            exists: true)
        )
      ]

      firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

      firestore.update document_path, update_data
    end

    it "SERVER_TIME with dotted field" do
      update_data = { "a.b.c": :SERVER_TIME }

      update_writes = [
        Google::Firestore::V1beta1::Write.new(
          transform: Google::Firestore::V1beta1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1beta1::DocumentTransform::FieldTransform.new(
                field_path: "a.b.c",
                set_to_server_value: :REQUEST_TIME
              )
            ]
          ),
          current_document: Google::Firestore::V1beta1::Precondition.new(
            exists: true)
        )
      ]

      firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

      firestore.update document_path, update_data
    end

    it "multiple SERVER_TIME fields" do
      update_data = { a: 1, b: :SERVER_TIME, c: { d: :SERVER_TIME } }

      update_writes = [
        Google::Firestore::V1beta1::Write.new(
          update: Google::Firestore::V1beta1::Document.new(
            name: "projects/projectID/databases/(default)/documents/C/d",
            fields: {
              "a" => Google::Firestore::V1beta1::Value.new(integer_value: 1)
            }
          ),
          update_mask: Google::Firestore::V1beta1::DocumentMask.new(
            field_paths: ["a"]
          ),
          current_document: Google::Firestore::V1beta1::Precondition.new(
            exists: true)
        ),
        Google::Firestore::V1beta1::Write.new(
          transform: Google::Firestore::V1beta1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1beta1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                set_to_server_value: :REQUEST_TIME
              ),
              Google::Firestore::V1beta1::DocumentTransform::FieldTransform.new(
                field_path: "c.d",
                set_to_server_value: :REQUEST_TIME
              )
            ]
          )
        )
      ]

      firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

      firestore.update document_path, update_data
    end

    it "nested SERVER_TIME field" do
      update_data = { a: 1, b: { c: :SERVER_TIME } }

      update_writes = [
        Google::Firestore::V1beta1::Write.new(
          update: Google::Firestore::V1beta1::Document.new(
            name: "projects/projectID/databases/(default)/documents/C/d",
            fields: {
              "a" => Google::Firestore::V1beta1::Value.new(integer_value: 1)
            }
          ),
          update_mask: Google::Firestore::V1beta1::DocumentMask.new(
            field_paths: ["a"]
          ),
          current_document: Google::Firestore::V1beta1::Precondition.new(
            exists: true)
        ),
        Google::Firestore::V1beta1::Write.new(
          transform: Google::Firestore::V1beta1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1beta1::DocumentTransform::FieldTransform.new(
                field_path: "b.c",
                set_to_server_value: :REQUEST_TIME
              )
            ]
          )
        )
      ]

      firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

      firestore.update document_path, update_data
    end

    it "SERVER_TIME cannot be anywhere inside an array value" do
      update_data = { a: [1, { b: :SERVER_TIME }] }

      error = expect do
        firestore.update document_path, update_data
      end.must_raise ArgumentError
      error.message.must_equal "cannot nest SERVER_TIME under arrays"
    end

    it "SERVER_TIME cannot be in an array value" do
      update_data = { a: [1, 2, :SERVER_TIME] }

      error = expect do
        firestore.update document_path, update_data
      end.must_raise ArgumentError
      error.message.must_equal "cannot nest SERVER_TIME under arrays"
    end

    it "SERVER_TIME with data" do
      update_data = { a: 1, b: :SERVER_TIME }

      update_writes = [
        Google::Firestore::V1beta1::Write.new(
          update: Google::Firestore::V1beta1::Document.new(
            name: "projects/projectID/databases/(default)/documents/C/d",
            fields: {
              "a" => Google::Firestore::V1beta1::Value.new(integer_value: 1)
            }
          ),
          update_mask: Google::Firestore::V1beta1::DocumentMask.new(
            field_paths: ["a"]
          ),
          current_document: Google::Firestore::V1beta1::Precondition.new(
            exists: true)
        ),
        Google::Firestore::V1beta1::Write.new(
          transform: Google::Firestore::V1beta1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1beta1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                set_to_server_value: :REQUEST_TIME
              )
            ]
          )
        )
      ]

      firestore_mock.expect :commit, commit_resp, [database_path, update_writes, options: default_options]

      firestore.update document_path, update_data
    end
  end
end
