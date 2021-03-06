require 'test_helper'

class UserUiStateTest < ActiveSupport::TestCase

  test "non existing destination" do
    user = users(:edit_on_agent_weather)
    agent = agents(:weather)
    user.ui_state = {"last_agent_move"=>"414211c7-d6cb-44f1-8b0c-bb6c192b92b6"}
    assert user.save
    user_state = UserUiState.new(user)
    assert_nil user_state.last_destination_agent(agent)
  end


  test "existing destination" do
    user = users(:admin)
    agent = agents(:weather)
    destination_agent_id = agents(:terminator).id
    user.ui_state = {"last_agent_move"=>destination_agent_id}
    assert user.save
    user_state = UserUiState.new(user)
    assert_not_nil user_state.last_destination_agent(agent)
  end


  test "agent locale" do
    # Initial state
    agent = agents(:weather)
    user = users(:edit_on_agent_weather)
    user_state = UserUiState.new(user)
    assert_equal agent.ordered_locales.first, user_state.agent_locale(agent)

    # Set existing locale for agent weather
    user_state.agent_locale = "fr"
    assert user_state.save

    user_state = UserUiState.new(user)
    assert_equal "fr", user_state.agent_locale(agent)

    # Set missing locale for agent weather
    user_state.agent_locale = "pt"
    assert user_state.save

    user_state = UserUiState.new(user)
    assert_equal "*", user_state.agent_locale(agent)
  end


  test "play_agents_selection" do
    # Initial state
    user = users(:edit_on_agent_weather)
    user_state = UserUiState.new(user)
    assert_equal [], user_state.play_agents_selection

    # Set play_agents_selection
    user_state.play_agents_selection = [agents(:terminator).id, agents(:weather).id]
    assert user_state.save

    user_state = UserUiState.new(user)
    assert_equal [agents(:terminator).id, agents(:weather).id].sort, user_state.play_agents_selection.sort
  end


  test "play_search" do
    # Initial state
    user = users(:edit_on_agent_weather)
    user_state = UserUiState.new(user)
    expected = {}
    assert_equal expected, user_state.play_search

    # Set play_search
    user_state.play_search = { "text" => "Hello" }
    assert user_state.save

    user_state = UserUiState.new(user)
    expected = { "text" => "Hello" }
    assert_equal expected, user_state.play_search
  end

end
