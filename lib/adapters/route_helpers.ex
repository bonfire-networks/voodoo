defmodule Voodoo.RouteHelpers do
  @moduledoc """
  Legacy route generation using deprecated `Phoenix.Router.Helpers`.
  
  This module can provide compatibility for older Phoenix versions by wrapping the existing Phoenix path helpers. Use `Voodoo.PathBuilder` for new code.
  
  To use this legacy mode, configure:
  
      config :voodoo, route_adapter: Voodoo.RouteHelpers
  """

  @doc """
  Generates reverse router clauses using Phoenix.Router.Helpers (deprecated approach).
  """
  def handle_clauses(name, router_module, filter_module_fn) do
    routes = router_module.__routes__()

    routes
    |> Enum.flat_map(&route_clauses(name, router_module, filter_module_fn, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
    |> Enum.reject(&is_nil/1)
  end

  defp route_clauses(name, router_module, filter_module_fn, route = %{path: path}) do
    places = inspect_path(path)

    case route do
      %{helper: nil} ->
        nil

      %{metadata: %{phoenix_live_view: {plug, action}}} ->
        if filter_module(plug, filter_module_fn),
          do: live_clauses(name, router_module, plug, action, route, places)

      %{metadata: %{phoenix_live_view: {plug, action, _, _}}} ->
        if filter_module(plug, filter_module_fn),
          do: live_clauses(name, router_module, plug, action, route, places)

      %{plug: plug, plug_opts: action} ->
        if filter_module(plug, filter_module_fn),
          do: plug_clauses(name, router_module, plug, action, route, places)
    end ||
      []
  end

  defp filter_module(plug, {module, fun}) do
    apply(module, fun, [plug])
  end

  defp filter_module(_, _), do: true

  # ...existing live_clauses, plug_clauses implementations...
  defp live_clauses(name, router_module, plug, nil, route = %{helper: "live"}, places) do
    args = [plug] ++ Macro.generate_arguments(places, __MODULE__)
    qs = Macro.var(:qs, __MODULE__)
    helper = route_helper(router_module, route)

    [
      {3 + places, clause(name, args ++ [qs], helper)},
      {2 + places, clause(name, args, helper)}
    ]
  end

  defp live_clauses(name, router_module, plug, nil, route, places) do
    args = Macro.generate_arguments(places, __MODULE__)
    qs = Macro.var(:qs, __MODULE__)
    helper = route_helper(router_module, route)
    id = String.to_atom(route.helper)

    [
      {3 + places, clause(name, [plug | args] ++ [qs], [plug | args] ++ [qs], helper)},
      {2 + places, clause(name, [plug | args], [plug | args], helper)},
      {3 + places, clause(name, [id | args] ++ [qs], [plug | args] ++ [qs], helper)},
      {2 + places, clause(name, [id | args], [plug | args], helper)}
    ]
  end

  defp live_clauses(name, router_module, plug, action, route = %{helper: "live"}, places) do
    args = [plug, action] ++ Macro.generate_arguments(places, __MODULE__)
    qs = Macro.var(:qs, __MODULE__)
    helper = route_helper(router_module, route)

    [
      {4 + places, clause(name, args ++ [qs], helper)},
      {3 + places, clause(name, args, helper)}
    ]
  end

  defp live_clauses(name, router_module, plug, action, route, places) do
    args = [action] ++ Macro.generate_arguments(places, __MODULE__)
    qs = Macro.var(:qs, __MODULE__)
    id = String.to_atom(route.helper)
    helper = route_helper(router_module, route)

    [
      {4 + places, clause(name, [plug | args] ++ [qs], helper)},
      {3 + places, clause(name, [plug | args], helper)},
      {4 + places, clause(name, [id | args] ++ [qs], args ++ [qs], helper)},
      {3 + places, clause(name, [id | args], args, helper)}
    ]
  end

  defp plug_clauses(name, router_module, plug, :index = action, route, places) do
    places_args = Macro.generate_arguments(places, __MODULE__)
    args = [action] ++ places_args
    qs = Macro.var(:qs, __MODULE__)
    id = String.to_atom(route.helper)
    helper = route_helper(router_module, route)

    [
      {2 + places, clause(name, [plug | places_args], args, helper)},
      {2 + places, clause(name, [id | places_args], args, helper)}
    ] ++ do_plug_clauses(name, places, plug, id, args, qs, helper)
  end

  defp plug_clauses(name, router_module, plug, action, route, places) do
    args = [action] ++ Macro.generate_arguments(places, __MODULE__)
    qs = Macro.var(:qs, __MODULE__)
    id = String.to_atom(route.helper)
    helper = route_helper(router_module, route)

    do_plug_clauses(name, places, plug, id, args, qs, helper)
  end

  defp do_plug_clauses(name, places, plug, id, args, qs, helper) do
    [
      {4 + places, clause(name, [plug | args] ++ [qs], args ++ [qs], helper)},
      {3 + places, clause(name, [plug | args], args, helper)},
      {4 + places, clause(name, [id | args] ++ [qs], args ++ [qs], helper)},
      {3 + places, clause(name, [id | args], args, helper)}
    ]
  end

  defp route_helper(router_module, %{helper: helper}) do
    helpers = Module.concat(router_module, Helpers)
    {:., [], [helpers, String.to_atom(helper <> "_path")]}
  end

  defp clause(name, args, helper), do: clause(name, args, args, helper)

  defp clause(name, params, args, helper) do
    if helper_exists(helper, args) do
      conn = Macro.var(:conn_or_socket_or_endpoint, __MODULE__)
      call = {helper, [], [conn | args]}

      quote do
        def unquote(name)(unquote(conn), unquote_splicing(params)) do
          unquote(call)
        end
      end
    end
  end

  defp helper_exists({:., [], [module, fun]}, args) do
    function_exported?(module, fun, 1 + Enum.count(args))
  end

  defp inspect_path(path, places \\ 0)
  defp inspect_path(<<>>, places), do: places

  defp inspect_path(<<":", rest::binary>>, places),
    do: inspect_path(rest, places + 1)

  defp inspect_path(<<"*", _rest::binary>>, places), do: places + 1

  defp inspect_path(<<_::utf8, rest::binary>>, places),
    do: inspect_path(rest, places)
end
