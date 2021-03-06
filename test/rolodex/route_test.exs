defmodule Rolodex.RouteTest do
  use ExUnit.Case

  alias Phoenix.Router
  alias Rolodex.Mocks.{TestController, TestRouter, User}

  alias Rolodex.{Config, Route}

  describe "#matches_filter?/2" do
    setup [:setup_config]

    test "Always returns false when no filters provided", %{config: config} do
      routes =
        TestRouter.__routes__()
        |> Enum.map(&Route.new(&1, config))

      assert routes |> Enum.at(0) |> Route.matches_filter?(config) == false
      assert routes |> Enum.at(1) |> Route.matches_filter?(config) == false
    end

    test "Returns true when for a route that matches a filter map", %{config: config} do
      config = %Config{config | filters: [%{path: "/api/demo", verb: :get}]}

      routes =
        TestRouter.__routes__()
        |> Enum.map(&Route.new(&1, config))

      assert routes |> Enum.at(0) |> Route.matches_filter?(config) == true
      assert routes |> Enum.at(1) |> Route.matches_filter?(config) == false
    end

    test "Returns true for a route that matches a filter function", %{config: config} do
      config = %Config{
        config
        | filters: [
            fn
              %Route{path: "/api/demo/:id", verb: :post} ->
                true

              _ ->
                false
            end
          ]
      }

      routes =
        TestRouter.__routes__()
        |> Enum.map(&Route.new(&1, config))

      assert routes |> Enum.at(0) |> Route.matches_filter?(config) == false
      assert routes |> Enum.at(1) |> Route.matches_filter?(config) == true
    end
  end

  describe "#new/2" do
    setup [:setup_config]

    test "It builds a new Rolodex.Route for the specified controller action", %{config: config} do
      phoenix_route = %Router.Route{
        plug: TestController,
        opts: :index,
        path: "/v2/test",
        pipe_through: [],
        verb: :get
      }

      result = Route.new(phoenix_route, config)

      assert result == %Route{
               desc: "It's a test!",
               headers: %{
                 "X-Request-Id" => %{type: :uuid, required: true}
               },
               body: %{
                 type: :object,
                 properties: %{
                   id: %{type: :uuid},
                   name: %{type: :string, desc: "The name"}
                 }
               },
               query_params: %{
                 id: %{
                   type: :string,
                   maximum: 10,
                   minimum: 0,
                   required: false,
                   default: 2
                 },
                 update: %{type: :boolean}
               },
               path_params: %{
                 account_id: %{type: :uuid}
               },
               responses: %{
                 200 => %{type: :ref, ref: User},
                 201 => %{
                   type: :list,
                   of: [%{type: :ref, ref: User}]
                 },
                 404 => %{
                   type: :object,
                   properties: %{
                     status: %{type: :integer},
                     message: %{type: :string}
                   }
                 }
               },
               metadata: %{public: true},
               tags: ["foo", "bar"],
               path: "/v2/test",
               pipe_through: [],
               verb: :get
             }
    end

    test "It merges controller action params into pipeline params", %{config: config} do
      phoenix_route = %Router.Route{
        plug: TestController,
        opts: :index,
        path: "/v2/test",
        pipe_through: [:web],
        verb: :get
      }

      result = Route.new(phoenix_route, config)

      assert result == %Route{
               desc: "It's a test!",
               headers: %{
                 "X-Request-Id" => %{type: :uuid, required: true}
               },
               body: %{
                 type: :object,
                 properties: %{
                   id: %{type: :uuid},
                   name: %{type: :string, desc: "The name"},
                   foo: %{type: :string}
                 }
               },
               query_params: %{
                 id: %{
                   type: :string,
                   maximum: 10,
                   minimum: 0,
                   required: false,
                   default: 2
                 },
                 update: %{type: :boolean},
                 foo: %{type: :string},
                 bar: %{type: :boolean}
               },
               path_params: %{
                 account_id: %{type: :uuid}
               },
               responses: %{
                 200 => %{type: :ref, ref: User},
                 201 => %{
                   type: :list,
                   of: [%{type: :ref, ref: User}]
                 },
                 404 => %{
                   type: :object,
                   properties: %{
                     status: %{type: :integer},
                     message: %{type: :string}
                   }
                 }
               },
               metadata: %{public: true},
               tags: ["foo", "bar"],
               path: "/v2/test",
               pipe_through: [:web],
               verb: :get
             }
    end

    test "Controller action params will win if in conflict with pipeline params", %{
      config: config
    } do
      phoenix_route = %Router.Route{
        plug: TestController,
        opts: :conflicted,
        path: "/v2/test",
        pipe_through: [:api],
        verb: :get
      }

      %Route{headers: headers} = Route.new(phoenix_route, config)
      assert headers == %{"X-Request-Id" => %{type: :string, required: true}}
    end

    test "It handles an undocumented route" do
      phoenix_route = %Router.Route{
        plug: TestController,
        opts: :undocumented,
        path: "/v2/test",
        pipe_through: [],
        verb: :post
      }

      assert Route.new(phoenix_route, Config.new()) == %Route{
               desc: "",
               headers: %{},
               body: %{},
               query_params: %{},
               responses: %{},
               metadata: %{},
               tags: [],
               path: "/v2/test",
               pipe_through: [],
               verb: :post
             }
    end

    test "It handles a missing controller action" do
      phoenix_route = %Router.Route{
        plug: TestController,
        opts: :does_not_exist,
        path: "/v2/test",
        pipe_through: [],
        verb: :post
      }

      assert Route.new(phoenix_route, Config.new()) == nil
    end
  end

  def setup_config(_) do
    config =
      Config.new(%{
        pipelines: %{
          api: %{
            headers: %{"X-Request-Id" => %{type: :uuid, required: true}},
            query_params: %{foo: :string}
          },
          web: %{
            body: %{
              type: :object,
              properties: %{foo: :string}
            },
            headers: %{"X-Request-Id" => %{type: :uuid, required: true}},
            query_params: %{foo: :string, bar: :boolean}
          },
          socket: %{
            headers: %{bar: :baz}
          }
        }
      })

    [config: config]
  end
end
