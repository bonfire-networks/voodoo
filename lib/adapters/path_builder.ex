defmodule Voodoo.PathBuilder do
  @moduledoc """
  Builds URL paths from route patterns without depending on deprecated `Phoenix.Router.Helpers`.

  Instead of calling `user_path(conn, :show, 1)`, we extract the pattern `/users/:id` and interpolate it with the provided arguments at runtime.
  """

  import Untangle

  @doc """
  Extracts route information and generates path builder clauses.

  Returns a list of function clauses that can be used to build paths from route patterns and arguments.
  """
  def handle_clauses(name, router_module, filter_module_fn) do
    routes = router_module.__routes__()

    routes
    |> Enum.flat_map(&route_clauses(name, filter_module_fn, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
    |> Enum.reject(&is_nil/1)
  end

  defp route_clauses(name, filter_module_fn, route = %{path: path}) do
    places = inspect_path(path)
    params = extract_params(path)

    case route do
      %{helper: nil} ->
        nil

      %{metadata: %{phoenix_live_view: {plug, action}}} ->
        if filter_module(plug, filter_module_fn),
          do: live_clauses(name, plug, action, route, places, params)

      %{metadata: %{phoenix_live_view: {plug, action, _, _}}} ->
        if filter_module(plug, filter_module_fn),
          do: live_clauses(name, plug, action, route, places, params)

      %{plug: plug, plug_opts: action} ->
        if filter_module(plug, filter_module_fn),
          do: plug_clauses(name, plug, action, route, places, params)
    end ||
      []
  end

  defp filter_module(plug, {module, fun}) do
    apply(module, fun, [plug])
  end

  defp filter_module(_, _), do: true

  defp live_clauses(name, plug, nil, route = %{helper: "live"}, places, params) do
    args = [plug] ++ Macro.generate_arguments(places, __MODULE__)
    qs = Macro.var(:qs, __MODULE__)

    [
      {3 + places, clause(name, args ++ [qs], params, route)},
      {2 + places, clause(name, args, params, route)}
    ]
  end

  defp live_clauses(name, plug, nil, route, places, params) do
    args = Macro.generate_arguments(places, __MODULE__)
    qs = Macro.var(:qs, __MODULE__)
    id = String.to_atom(route.helper)

    [
      {3 + places, clause(name, [plug | args] ++ [qs], [plug | args] ++ [qs], params, route)},
      {2 + places, clause(name, [plug | args], [plug | args], params, route)},
      {3 + places, clause(name, [id | args] ++ [qs], [plug | args] ++ [qs], params, route)},
      {2 + places, clause(name, [id | args], [plug | args], params, route)}
    ]
  end

  defp live_clauses(name, plug, action, route = %{helper: "live"}, places, params) do
    args = [plug, action] ++ Macro.generate_arguments(places, __MODULE__)
    qs = Macro.var(:qs, __MODULE__)

    [
      {4 + places, clause(name, args ++ [qs], params, route)},
      {3 + places, clause(name, args, params, route)}
    ]
  end

  defp live_clauses(name, plug, action, route, places, params) do
    args = [action] ++ Macro.generate_arguments(places, __MODULE__)
    qs = Macro.var(:qs, __MODULE__)
    id = String.to_atom(route.helper)

    [
      {4 + places, clause(name, [plug | args] ++ [qs], params, route)},
      {3 + places, clause(name, [plug | args], params, route)},
      {4 + places, clause(name, [id | args] ++ [qs], args ++ [qs], params, route)},
      {3 + places, clause(name, [id | args], args, params, route)}
    ]
  end

  defp plug_clauses(name, plug, :index = action, route, places, params) do
    places_args = Macro.generate_arguments(places, __MODULE__)
    qs = Macro.var(:qs, __MODULE__)
    id = String.to_atom(route.helper)

    # For :index action, generate clauses that match on [plug] or [id] 
    # but only pass places_args (no action) to interpolation
    [
      {2 + places, clause(name, [plug | places_args], places_args, params, route)},
      {2 + places, clause(name, [id | places_args], places_args, params, route)}
    ] ++ do_plug_clauses(name, plug, id, places_args, qs, params, route)
  end

  defp plug_clauses(name, plug, action, route, places, params) do
    places_args = Macro.generate_arguments(places, __MODULE__)
    qs = Macro.var(:qs, __MODULE__)
    id = String.to_atom(route.helper)

    do_plug_clauses(name, plug, id, places_args, qs, params, route)
  end

  defp do_plug_clauses(name, plug, id, places_args, qs, params, route) do
    # All controller clauses should pass only places_args to interpolation
    # The action atoms are only for pattern matching
    [
      {4 + length(places_args),
       clause(name, [plug | places_args] ++ [qs], places_args ++ [qs], params, route)},
      {3 + length(places_args), clause(name, [plug | places_args], places_args, params, route)},
      {4 + length(places_args),
       clause(name, [id | places_args] ++ [qs], places_args ++ [qs], params, route)},
      {3 + length(places_args), clause(name, [id | places_args], places_args, params, route)}
    ]
  end

  defp clause(name, args, param_names, route), do: clause(name, args, args, param_names, route)

  defp clause(name, params, args, param_names, route) do
    conn = Macro.var(:conn_or_socket_or_endpoint, __MODULE__)
    path_pattern = route.path

    # Build the path by calling our interpolation function
    call =
      quote do
        Voodoo.PathBuilder.interpolate_path(
          unquote(path_pattern),
          unquote(param_names),
          unquote(args)
        )
      end

    quote do
      def unquote(name)(unquote(conn), unquote_splicing(params)) do
        unquote(call)
      end
    end
  end

  @doc """
  Interpolates a path pattern with the given arguments.

  Filters out module atoms (used for routing) before interpolation.

  ## Examples

      iex> interpolate_path("/users/:id", [:id], [123])
      "/users/123"
      
      iex> interpolate_path("/@:username", [:username], [Bonfire.Data.Identity.Character, "mayel"])
      "/@mayel"
      
      iex> interpolate_path("/posts/:post_id/comments/:id", [:post_id, :id], [5, 10])
      "/posts/5/comments/10"
      
      iex> interpolate_path("/feed", [], [])
      "/feed"
      
      iex> interpolate_path("/users/:id", [:id], [123, %{page: 2}])
      "/users/123?page=2"
  """
  def interpolate_path(pattern, param_names, args) when is_list(args) do
    # Debug what we're receiving
    debug(
      "PathBuilder interpolate_path: pattern=#{pattern}, param_names=#{inspect(param_names)}, args=#{inspect(args)}"
    )

    # Filter out module atoms (used for routing) before interpolation
    filtered_args = filter_module_atoms(args)
    debug("PathBuilder after filter: filtered_args=#{inspect(filtered_args)}")

    # Separate path params from query string
    {path_args, query_args} = split_args(filtered_args, length(param_names))
    debug("PathBuilder split: path_args=#{inspect(path_args)}, query_args=#{inspect(query_args)}")

    # Build the base path
    path = build_path(pattern, param_names, path_args)
    debug("PathBuilder result: #{path}")

    # Append query string if present
    append_query_string(path, query_args)
  end

  # Filter out atoms that look like module names OR controller actions
  defp filter_module_atoms(args) do
    Enum.reject(args, fn
      atom when is_atom(atom) and not is_nil(atom) ->
        atom_str = Atom.to_string(atom)
        # Only filter module names (contain dots or start with Elixir.)
        String.starts_with?(atom_str, "Elixir.") or String.contains?(atom_str, ".")

      _ ->
        false
    end)
  end

  defp split_args(args, param_count) do
    path_args = Enum.take(args, param_count)
    query_args = Enum.drop(args, param_count) |> List.first()

    {path_args, query_args}
  end

  defp build_path(pattern, param_names, args) do
    # Zip param names with their values
    replacements = Enum.zip(param_names, args) |> Map.new()

    # Replace each :param in the pattern with its value
    Enum.reduce(replacements, pattern, fn {param_name, value}, acc ->
      param_str = ":#{param_name}"
      value_str = to_string(value)
      String.replace(acc, param_str, value_str)
    end)
  end

  defp append_query_string(path, nil), do: path
  defp append_query_string(path, []), do: path

  defp append_query_string(path, query_params)
       when is_map(query_params) or is_list(query_params) do
    query_string =
      query_params
      |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
      |> URI.encode_query()

    case query_string do
      "" -> path
      qs -> "#{path}?#{qs}"
    end
  end

  defp append_query_string(path, _), do: path

  @doc """
  Extracts parameter names from a route path pattern.

  ## Examples

      iex> extract_params("/users/:id")
      [:id]
      
      iex> extract_params("/posts/:post_id/comments/:id")
      [:post_id, :id]
      
      iex> extract_params("/feed")
      []
  """
  def extract_params(path) do
    ~r/:([a-z_]+)/
    |> Regex.scan(path, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.to_atom/1)
  end

  defp inspect_path(path, places \\ 0)
  defp inspect_path(<<>>, places), do: places

  defp inspect_path(<<":", rest::binary>>, places),
    do: inspect_path(rest, places + 1)

  defp inspect_path(<<"*", _rest::binary>>, places), do: places + 1

  defp inspect_path(<<_::utf8, rest::binary>>, places),
    do: inspect_path(rest, places)
end
