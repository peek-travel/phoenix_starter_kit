defmodule PhoenixStarterKit.Test.PeekProMock do
  @moduledoc false
  def mock_response("get_activities", _query, _variables) do
    %Tesla.Env{status: 200, body: %{data: %{activities: [%{id: "some-activity-id"}]}}}
  end
end
