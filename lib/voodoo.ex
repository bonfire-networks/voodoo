defmodule Voodoo do
  # @moduledoc """
  # Declares a config-overrideable router.

  # ```
  # use Voodoo, otp_app: :myapp


  # ```
  # """


  @doc """
  Generates a reverse router function with the given name based upon a
  compiled(!) phoenix router module.

  Must be used outside of the router module, or else the router won't
  be compiled yet and we won't be able to look up the routes.

  Generated function wraps the existing phoenix helpers.

  ```
  defmodule MyAppWeb.Router do
    use MyAppWeb, :router
    # ...
  end
  defmodule MyAppWeb.Router.Reverse do
    import Voodoo, only: [def_reverse_router: 2]
    def_reverse_router :path, for: MyAppWeb.Router
  end
  ```
  """
  defmacro def_reverse_router(name, opts) do
    quote do
      require Voodoo.Reverse
      Voodoo.Reverse.def_reverse_router(unquote(name), unquote(opts))
    end
  end

  @doc """
  Turns a Conn or Socket into the name of the router that routed it.
  """
  @spec router(Conn.t | Socket.t) :: module
  def router(%{private: %{phoenix_router: router}}), do: router
  def router(%{__struct__: _, router: router}), do: router

  # defmacro __using__(options) do
  #   otp_app = Keyword.fetch!(options, :otp_app)
  #   caller = __CALLER__
  #   Module.register_attribute(caller.module, :otp_app)
  #   Module.register_attribute(caller.module, :voodoo_children, accumulate: true)
  #   quote do
  #     @otp_app unquote(otp_app)
  #     import Voodoo
  #     # @before_compile {:before_compile, {
  #     unquote(before_compile_macro(caller))
  #   end
  # end

  # defp before_compile_macro(caller) do
  #   quote do
  #     defmacro __before_compile__(env) do
  #       unquote(using_macro(caller, env))
  #     end
  #   end
  # end

  # defp using_macro(caller, env) do

  #   # quote do
  #   #   defmacro __using__(_opts) do

  #   #   end
  #   # end
  # end

  # defp voodoo_child(params) do
  #   quote do
  #     @voodoo_children unquote(params)
  #   end
  # end

  # defmacro get(path, controller, action, opts \\ []), do: voodoo_child([:get, path, controller, action])

  # defmacro scope(opts, list), do: voodoo_child(opts, list)
  # defmacro scope(path, opts, list), do: voodoo_child(path, opts, list)
  # defmacro scope(path, alias, opts, list), do: voodoo_child(path, alias, opts, list)

end
