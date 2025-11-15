defmodule Voodoo.Reverse do
  @moduledoc """
  Generates reverse router functions.

  By default uses pattern-based path building (`Voodoo.PathBuilder`).

  To use legacy `Phoenix.Router.Helpers` mode:

      config :voodoo, route_adapter: Voodoo.RouteHelpers
  """

  defmacro def_reverse_router(name, opts) when is_atom(name) and is_list(opts) do
    with router_module = {:__aliases__, _, _} <- opts[:for] do
      router_module = Macro.expand(router_module, __CALLER__)
      Code.ensure_loaded(router_module)
      filter_module = Macro.expand(opts[:filter][:module], __CALLER__)

      filter_module_fn =
        if not is_nil(filter_module) and Code.ensure_loaded?(filter_module) do
          {filter_module, opts[:filter][:fun]}
        else
          {Code, :ensure_loaded?}
        end

      quote do
        (unquote_splicing(reverse_router_clauses(name, router_module, filter_module_fn)))
      end
    end
  end

  @doc """
  Generates reverse router clauses using the configured adapter.

  Uses `Voodoo.PathBuilder` by default.
  """
  def reverse_router_clauses(name, router_module, filter_module_fn) do
    if adapter = Application.get_env(:voodoo, :route_adapter, Voodoo.PathBuilder) do
      adapter.handle_clauses(name, router_module, filter_module_fn)
    else
      raise "No :route_adapter configured for :voodoo"
    end
  end
end
