defmodule Consola do
  @moduledoc """
  interfaz de texto de el sistema. aqui muestra los indicadores, lee los comandos que
  escribe el usuario y da respuesta, hasta que el usuario escribe `salir` para finalizar todo.

  da inicio con mix consola.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  @doc """
  Muestra el mensaje de bienvenida y empieza a leer comandos.
  muestra el mensaje de bienvenida a el usuario y comienza a leer comandos

  al inicio no hay ningun usuario conectado.
  """
  def iniciar do
    Util.mostrar_mensaje(" Sistema de coordinacion y gestion para emergencias de la Uniquindio ")
    Util.mostrar_mensaje("para obtener los comandos, escriba ayuda.")
    ciclo(nil)
  end

  # esta es una funcion recursiva, lee un comando, lo ejecuta y vuelve a esperar el siguiente.
  # usuario es el usuario activo en la consola (nil si nadie se ha conectado).
  defp ciclo(usuario) do
    linea = Util.ingresar(indicador(usuario), :texto)

    case Comandos.ejecutar(linea, usuario) do
      :salir ->
        # Antes de cerrar, espera a que la bitacora guarde la actividad que le falta
        Bitacora.terminar_pendientes()
        Util.mostrar_mensaje("cerrar sesion, vuelva pronto, este programa siempre estara a su disposicion.")

      {nuevo_usuario, {:ok, texto}} ->
        Util.mostrar_mensaje(texto)
        ciclo(nuevo_usuario)

      {nuevo_usuario, {:error, texto}} ->
        Util.mostrar_error("error: " <> texto)
        ciclo(nuevo_usuario)
    end
  end

  # Texto que se muestra antes de cada comando, con el usuario conectado
  defp indicador(nil), do: "\n[sin sesion]> "
  defp indicador(usuario), do: "\n[#{usuario}]> "
end
