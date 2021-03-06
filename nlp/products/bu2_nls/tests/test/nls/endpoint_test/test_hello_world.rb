require 'test_helper'

module Nls

  module EndpointTest

    class TestHelloWorld < NlsTestCommon

      def test_hello_world

        expected =
        {
          "hello" => "world"
        }

        actual = Nls.query_get(Nls.url_test)
        assert_equal expected, actual, "Get"

        actual = Nls.query_post(Nls.url_test)
        assert_equal expected, actual, "Post"

      end

      def test_hello_toto

        data = {
          name: "toto"
        }

        expected = {
          "hello" => "toto"
        }

        actual = Nls.query_get(Nls.url_test, data)
        assert_equal expected, actual, "Get"

        actual = Nls.query_post(Nls.url_test, data)
        assert_equal expected, actual, "Post by body"

        actual = Nls.query_post(Nls.url_test, {}, data)
        assert_equal expected, actual, "Post by param"

      end

      def test_json_bad_formatted

        exception = assert_raises RestClient::ExceptionWithResponse do
          RestClient.post(Nls.url_test, "{\"toto\"}", content_type: :json)
        end

        expected_error = "OgListeningProcessSearchRequest : Your json contains error in"

        assert_response_has_error expected_error, exception

      end

      def test_param_in_path

        # Url must be correctly encoded
        url = "#{Nls.url_test}/hello/my%20friends/of/pertimm/"

        data = {
          name: "toto"
        }

        expected = {
          "hello" => "toto",
          "path_param1" => "my friends",
          "path_param2" => "pertimm"
        }

        actual = Nls.query_get(url, data)
        assert_equal expected, actual

      end


    end

  end

end
