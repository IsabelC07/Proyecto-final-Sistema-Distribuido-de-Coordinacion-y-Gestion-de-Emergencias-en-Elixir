defmodule Mensaje do
  @moduledoc """
  en este modulo manejamos los mensajes que se le dejan a una persona reportada, por ejemplo cuando un familiar la esta buscando y quiere dejarle un aviso.

  cada mensaje tiene un id (por ejemplo MS001), la fecha, el usuario que lo manda, el documento de la persona a la que va y lo que dice.

  todos los mensajes empiezan en "pendiente" y despues se pueden marcar como "entregado".

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  defstruct id: "", fecha: "", remitente: "", destinatario: "", contenido: "", estado: "pendiente"

  @doc """
  esta funcion sirve para crear un mensaje nuevo, que empieza en "pendiente" y con la fecha del momento en que se crea.
  recibe el id, el remitente, el destinatario y el contenido.
  si el contenido esta vacio o solo tiene espacios no se crea el mensaje.
  devuelve `{:ok, mensaje}` o `{:error, mensaje_de_error}`.
  """
  def crear(id, remitente, destinatario, contenido) do
    if String.trim(contenido) == "" do
      {:error, "El mensaje no puede ir vacio"}
    else
      {:ok,
       %Mensaje{
         id: id,
         fecha: Util.fecha_actual(),
         remitente: remitente,
         destinatario: destinatario,
         contenido: contenido
       }}
    end
  end

  @doc """
  esta funcion le cambia el estado al mensaje, que solo puede ser "pendiente" o "entregado".
  da error si el estado no existe o si el mensaje ya estaba en ese estado.
  devuelve `{:ok, mensaje_actualizado}` o `{:error, mensaje_de_error}`.
  """
  def marcar(mensaje, estado) do
    cond do
      estado not in ["pendiente", "entregado"] ->
        {:error, "El mensaje solo se puede marcar como pendiente o entregado"}

      mensaje.estado == estado ->
        {:error, "El mensaje #{mensaje.id} ya estaba #{estado}"}

      true ->
        {:ok, %{mensaje | estado: estado}}
    end
  end

  @doc "esta funcion arma una linea de texto con los datos del mensaje, para mostrarla en pantalla."
  def describir(m) do
    "#{m.id} | #{m.fecha} | de: #{m.remitente} | para: #{m.destinatario} | #{m.estado} | #{m.contenido}"
  end
end
