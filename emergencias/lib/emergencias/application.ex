defmodule Emergencias.Application do
  @moduledoc """
  tenemos el punto de arranque de la app. da inicio a el arbol de supervision con la bitacora y todos los sercidores del sistema

  usamos una estrategia que aprendimos en la web de one for more: si el proceso falla, el supervisor
  hace reinicio solo de ese proceso, y este vuelve a cargar su informacion desde los archivos que se tienen

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  use Application

  # el codigo en elixir llama esta funcion al iniciar la pp (mix run, mix test, mix consola)
  @impl true
  def start(_tipo, _argumentos) do
    hijos = [
      Bitacora,
      UsuariosServer,
      ZonasServer,
      InventarioServer
    ]

    Supervisor.start_link(hijos, strategy: :one_for_one, name: Emergencias.Supervisor)
  end
end
