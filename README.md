# Voodoo

Configuration-driven plug routers.

<!-- ## Synopsis -->

<!-- ```elixir -->
<!-- defmodule MyApp.MyExtension.Router do -->
<!--   use Voodoo, otp_app: :my_app -->


<!--   get "/", HomeController, :index # Helpers.home_path(conn, :index) -->
<!--   resources "/wat", WatController -->

    
<!-- end -->
<!-- ``` -->

<!-- ```elixir -->
<!-- config :my_app, MyApp.Router, -->
<!--   routers: [ -->
<!--     MyApp.MyExtension.Router, -->
<!--     Blah.Router, -->
<!--   ] -->
  

<!-- config :my_app, MyApp.MyExtension.Router, -->
<!--   prefix: "/my_ext", -->
<!--   home: [index: [path: "/home"]], -->
<!--   wat: [ -->
<!--     path: "/what", -->
<!--     only: [:index], -->
<!--     index: [] -->
<!--   ] -->
  
```

<!-- ## Installation -->


<!-- If [available in Hex](https://hex.pm/docs/publish), the package can be installed -->
<!-- by adding `voodoo` to your list of dependencies in `mix.exs`: -->

<!-- ```elixir -->
<!-- def deps do -->
<!--   [ -->
<!--     {:voodoo, "~> 0.1.0"} -->
<!--   ] -->
<!-- end -->
<!-- ``` -->

<!-- Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) -->
<!-- and published on [HexDocs](https://hexdocs.pm). Once published, the docs can -->
<!-- be found at [https://hexdocs.pm/voodoo](https://hexdocs.pm/voodoo). -->

