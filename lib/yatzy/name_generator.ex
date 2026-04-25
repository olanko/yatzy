defmodule Yatzy.NameGenerator do
  @moduledoc """
  Haikunator-style Finnish game-name suggestions: `adjective-noun-NN`.

      iex> Yatzy.NameGenerator.generate()
      "utuinen-järvi-42"
  """

  @adjectives ~w(
    utuinen kirkas hiljainen kylmä lämmin tyyni raikas sumea kostea kuiva
    luminen jäinen tuulinen pilvinen aurinkoinen tähtinen unelias virkeä kiivas nopea
    hidas iloinen surullinen utelias rohkea arka viisas hupsu hassu kohtelias
    ystävällinen salainen piilevä avara ahdas korkea matala syvä laaja pieni
    iso valtava mahtava herkkä terävä tylsä pehmeä kova silkkinen karhea
    sileä kihara punainen sininen vihreä keltainen valkoinen musta ruskea harmaa
    violetti kullainen hopeinen metallinen puinen kiiltävä himmeä kimaltava säihkyvä liekehtivä
    hehkuva kuohuva tasainen epätasainen mehevä tuore kypsä raaka makea hapan
    kitkerä suolainen tulinen mieto salaperäinen taianomainen ihmeellinen uljas arvokas nöyrä
    ylpeä itsenäinen villi kesy nuori vanha ikuinen hetkellinen unohdettu kaunis kostea märkä
    kiimainen kankea jähmeä lätisevä kumiseva
  )

  @nouns ~w(
    järvi metsä meri ranta vuori tunturi niitty saari lampi joki
    puro koski lähde suo kallio kivi hiekka taivas pilvi tähti
    kuu aurinko sade lumi jää tuuli usva sumu utu revontuli
    salama ukkonen polku tie silta kettu susi karhu ilves hirvi
    peura poro jänis orava mäyrä saukko minkki piisami majava ahma
    supi kotka haukka pöllö korppi varis västäräkki peippo tilhi kuovi
    joutsen hanhi sorsa teeri metso kuikka hauki ahven lohi taimen
    siika silakka perhonen mehiläinen sammakko käärme sisilisko mustikka puolukka lakka
    mansikka vadelma herukka omena päärynä kantarelli tatti sieni peruna porkkana
    sipuli valkosipuli tilli ruisleipä korvapuusti pulla kahvi mehu piimä juusto tupas
    mätäs meisseli heijari tupsukka
  )

  def adjectives, do: @adjectives
  def nouns, do: @nouns

  @doc "Generate a `adjective-noun-NN` (NN ∈ 1..99) suggestion."
  def generate do
    adj = Enum.random(@adjectives)
    noun = Enum.random(@nouns)
    n = :rand.uniform(9999)
    "#{adj}-#{noun}-#{n}"
  end
end
