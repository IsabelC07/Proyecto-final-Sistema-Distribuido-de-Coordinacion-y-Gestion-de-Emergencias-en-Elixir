 # aqui tenemos el sistema distribuido de la coordinacion y la gestion de emergencias
 # Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
 # Licencia: GNU GPL v3

defmodule Emergencias.MixProject do
  use Mix.Project

  # aqui estan datos generales del proyecto, como el nombre, la version, la descripcion y las dependencias
  def project do
    [
      app: :emergencias,
      version: "0.1.0-beta.1",
      elixir: "~> 1.15",
      description: "el sistema de coordinacion y las gestiones de emergencias",
      start_permanent: Mix.env() == :prod,
      deps: [],
      aliases: [consola: "run -e Consola.iniciar()"]
    ]
  end


  # la apliacion que sera cargada y el modulo que da inicio asl sistema
  def application do
    [
      extra_applications: [:logger],
      mod: {Emergencias.Application, []}
    ]
  end
end
