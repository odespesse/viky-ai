require 'test_helper'

class ApiInternalTest < ActionDispatch::IntegrationTest

  VIKYAPP_INTERNAL_API_TOKEN = ENV.fetch("VIKYAPP_INTERNAL_API_TOKEN") { 'Uq6ez5IUdd' }

  test "Api internal get all packages" do
    get "/api_internal/packages.json", headers: { "Access-Token" => VIKYAPP_INTERNAL_API_TOKEN }

    assert_equal '200', response.code

    expected = [
      "30d3b81b-52f4-5fb3-a6f7-b2f025dece97",
      "930025d1-cfd0-5f27-8cb1-a0aecd1309fc",
      "fba88ff8-8238-5007-b3d8-b88fd504f94c",
      "794f5279-8ed5-5563-9229-3d2573f23051"
    ]
    assert_equal expected, JSON.parse(response.body)
  end

  test "Api internal get one package" do
    require 'fix_action_controller_live_threads_deadlock'

    agent = agents(:weather_confirmed)
    get api_internal_path(agent.id, format: :json), headers: { "Access-Token" => VIKYAPP_INTERNAL_API_TOKEN }

    assert_equal '200', response.code

    interpretation_question = interpretations(:weather_confirmed_question)
    entities_list_dates = entities_lists(:weather_confirmed_dates)
    expected = {
      "id"              => agent.id ,
      "slug"            => agent.slug,
      "interpretations" =>
        [{ "id"          => interpretation_question.id,
           "slug"        => interpretation_question.slug,
           "scope"       => 'private',
           "expressions" => []
         },
         { "id"          => entities_list_dates.id,
           "slug"        => entities_list_dates.slug,
           "scope"       => 'private',
           "expressions" => []
         }
        ]
    }
    assert_equal expected, JSON.parse(response.body)
  end

end
