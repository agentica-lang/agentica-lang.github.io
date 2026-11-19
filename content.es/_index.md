---
title: Agentica
description: Agentica es Ruby con tipos estáticos. Sintaxis parecida a Ruby, comprobada antes de ejecutar, con valores inmutables.
search: false
source_hash: "db7c435227ae"
---

# Agentica: Ruby con tipos estáticos {#agentica-ruby-with-static-types}

Agentica es un lenguaje de programación con tipos estáticos y sintaxis parecida a Ruby. Cada programa se comprueba antes de ejecutarse, y los valores nunca cambian en su lugar. Las tareas se ejecutan en paralelo en varios núcleos. Trae HTTP, TLS y WebSockets, paquetes y módulos nativos en C, todo en un solo binario, `agentica`.

```agentica
struct Book
  title: String
  pages: Int
end

def long?(book: Book) -> Bool
  book.pages > 300
end

def main() -> Void
  books = [
    Book(title: "Dune", pages: 412),
    Book(title: "Emma", pages: 192)
  ]
  books.each do |book|
    if long?(book)
      puts("#{book.title} is long")
    else
      puts("#{book.title} is short")
    end
  end

  total = books.map { |b| b.pages }.sum
  puts("#{total} pages in all")
end
```

Ejecútalo con `agentica books.agc`:

```output
Dune is long
Emma is short
604 pages in all
```

Escribe `pages: "412"` en su lugar y el programa no se ejecuta:

```text
books.agc:12:32 error[CHECK-TYPE-MISMATCH]
expected Int, found String

12 |     Book(title: "Dune", pages: "412"),
   |                                ^^^^^
   = help: convert it with s.to_i!
```

## Por qué Agentica {#why-agentica}

- **Se comprueba antes de ejecutarse.** Un tipo incorrecto es un error con un código estable y una posición en el código fuente, a menudo con una sugerencia, antes de que el programa empiece.
- **Los valores nunca cambian en su lugar.** Una función no puede cambiar la lista ni la estructura que le pasas.
- **Pequeño a propósito.** Hay pocas reglas, para que personas y agentes de IA puedan escribir, leer y corregir programas con pocas sorpresas.
- **Un solo binario.** `agentica` ejecuta, comprueba, formatea y prueba programas. Trae HTTP, TLS, WebSockets y paquetes integrados, y no necesita otra biblioteca.
- **Tareas en varios núcleos.** ¿Qué tan rápido es? Mira [una adaptación de Campfire medida frente a Go](/blog/campfire-faster-than-go/).

## Instalar {#install}

En Linux x86-64:

```sh
curl -fsSLO https://github.com/agentica-lang/agentica/releases/download/{{< release >}}/agentica-{{< release >}}-linux-x86_64.tar.gz
curl -fsSLO https://github.com/agentica-lang/agentica/releases/download/{{< release >}}/SHA256SUMS
sha256sum -c --ignore-missing SHA256SUMS
tar -xzf agentica-{{< release >}}-linux-x86_64.tar.gz
export PATH="$PWD/agentica-{{< release >}}-linux-x86_64/bin:$PATH"
agentica --version
```

Cada release tiene un archivo comprimido por sistema (Linux y macOS en x86-64 y arm64, Windows en x86-64), con `bin/agentica` dentro. La [guía para empezar](https://www.agentica-lang.com/agentica/getting-started/) lista los archivos, tiene un prompt que instala Agentica con tu agente de programación y ejecuta tu primer programa.

## Proyectos {#projects}

- [Documentación](https://www.agentica-lang.com/agentica/): el tour del lenguaje, la línea de comandos y la especificación.
- [Biblioteca](https://www.agentica-lang.com/agentica/library/): cada módulo integrado, con un ejemplo por función.
- [Bond](https://www.agentica-lang.com/bond/): un framework web para Agentica.
- [agentica-db](https://www.agentica-lang.com/agentica-db/): una sola API para PostgreSQL, SQLite y MySQL.
- [agentica-tui](https://www.agentica-lang.com/agentica-tui/): interfaces de terminal con un árbol de vistas con tipos y un bucle al estilo Elm.
- [Paquetes](https://www.agentica-lang.com/packages/): paquetes que puedes añadir a un proyecto.
- [Finn](https://www.agentica-lang.com/agc-agent/): un agente de programación para la terminal, escrito en Agentica.
- [cchecker](https://www.agentica-lang.com/cchecker/): comprueba código C con las reglas de un proyecto.
- [Ecosistema](/ecosystem/): cada framework, biblioteca y herramienta de editor alrededor de Agentica.
- [GitHub](https://github.com/agentica-lang): el código fuente del lenguaje y de cada proyecto.
