defmodule Bitacora do
  @moduledoc """
  proceso que registra la actividad de los usuarios que tenemos
  esta diciendo que comandos usaron y si salio bien o mal

  se construye con `spawn` + `receive`, como en el Problema 016.
  los procesos le envian un mensaje y siguen trabajando sin esperar
  a que la actividad sea ess crita en el archivo.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  @nombre :bitacora

  @doc """
  indica al supervisor como arranca el proceso, lo llama el supervisor automaticamente, no hace falta usarla manualmente
  """
  def child_spec(_argumento) do
    %{id: __MODULE__, start: {__MODULE__, :iniciar, []}}
  end

  @doc """
  da inicio al proceso de la bitacora, y lo registra con el nombre, que es :bitacora
  """
  def iniciar do
    pid = spawn_link(fn -> esperar_mensajes() end)

    Process.register(pid, @nombre)
    {:ok, pid}
  end

  @doc """

  envia a la vitacora una accion para que la guarde.

  * `usuario' que es quién hizo la acción.
  * `accion` que es el comando que uso.
  * `resultado` da `:ok` o da `:error`.

  no da tiempo a una espera de lo que responde, siempre devulve :ok de inmediato
  """
  def registrar(usuario, accion, resultado) do
    send(@nombre, {:registrar, usuario, accion, resultado})
    :ok
  end

  # Recursiva: atiende un mensaje, lo guarda en el archivo y vuelve a esperar el siguiente
  # tenemos recursividad, donde atiende un mensaje, lo guarda en el archivo y vuelve a esperar el que sigue
  defp esperar_mensajes do
    receive do
      {:registrar, usuario, accion, resultado} ->
        Persistencia.registrar_actividad(usuario, accion, resultado)
        esperar_mensajes()
    end
  end
end
