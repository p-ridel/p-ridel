# Manual Oficial do Desenvolvedor de Tenants — Plataforma Ridel

Bem-vindo ao **Manual do Desenvolvedor da Plataforma Ridel**. 

O Ridel foi projetado sob a premissa de **Spec-Driven e Declarative Development**: a Engine (Backend FastAPI e Frontend Universal Player Flutter) é fornecida como um contêiner imutável. Como desenvolvedor, **você não precisa alterar código do core, nem escrever HTML/CSS/Flutter, nem gerenciar migrações manuais de SQL**. Toda a sua aplicação é construída declarando entidades, regras e fluxos em Python dentro da pasta de tenants.

---

## 📁 1. Estrutura de Diretórios de um Tenant

Cada sistema ou cliente da plataforma reside como um subdiretório dentro de `/data/tenants/`:

```text
/data/tenants/<nome_do_tenant>/
├── __init__.py           # Identificador do pacote Python
├── app.py                # Configuração central de menus, ícones e submódulos
├── apps/                 # (Opcional) Submódulos organizados por domínio
│   ├── pedidos.py
│   └── financeiro.py
├── tables.py             # Modelagem declarativa de dados, campos e enums
├── views.py              # Declaração das telas (Grids, Forms, Kanbans, Detalhes)
├── roles.py              # Perfis de acesso, permissões CRUD e RBAC
├── actions.py            # Regras de negócio, botões na UI e mutações com @action
└── user.py               # Usuários pré-cadastrados no tenant e suas roles
```

---

## 🗄️ 2. Modelagem de Dados (`tables.py`)

No `tables.py`, você modela as tabelas do seu sistema. O Ridel utiliza essas definições para criar automaticamente os schemas e tabelas isoladas no PostgreSQL (*Multi-tenancy via Schemas*).

### Tipos de Campos Suportados
* `CharField(name, label, max_length=255, required=True, unique=False)`: Textos curtos.
* `IntegerField(name, label, min_value=0, max_value=1000)`: Números inteiros.
* `DecimalField(name, label, max_digits=10, decimal_places=2)`: Valores monetários e decimais.
* `BooleanField(name, label, default=False)`: Caixas de seleção (checkbox/switch).
* `DateTimeField(name, label, auto_now_add=True)`: Datas e horas com formatação automática.
* `ForeignKey(target_table, name, label, reference_label="nome")`: Relacionamento com outra tabela.
* `RelatedField(sublist_view, label)`: Campo virtual para embutir tabelas filhas na tela de detalhes.
* `EnumField(options, name, label)`: Seletores tipados.

### Enums Tipados com Cores (`EnumOptions`)
Para status e seletores de opções fixas, use classes herdando de `EnumOptions`:

```python
from ridel.core.fields import CharField, EnumField, ForeignKey, IntegerField, Table
from ridel.core.types import EnumOptions, Option

class StatusPedido(EnumOptions):
    RASCUNHO = Option("rascunho", label="Rascunho", color="#9E9E9E")
    PENDENTE = Option("pendente", label="Pendente de Aprovação", color="#FF9800")
    APROVADO = Option("aprovado", label="Aprovado", color="#4CAF50")
    CANCELADO = Option("cancelado", label="Cancelado", color="#F44336")

class PedidoTable(Table):
    name = "pedidos"
    label = "Pedidos de Venda"
    
    id = IntegerField("id", label="ID", primary_key=True, auto_increment=True)
    cliente_id = ForeignKey("clientes", "cliente_id", label="Cliente", reference_label="razao_social")
    valor_total = DecimalField("valor_total", label="Valor Total (R$)", default=0.0)
    status = EnumField(StatusPedido, "status", label="Situação", default=StatusPedido.RASCUNHO)
```

---

## 🖥️ 3. Interfaces e Telas (`views.py`)

No `views.py`, você define como os dados serão exibidos no **Universal Player Flutter Web**:

### Tipos de Views Disponíveis
* `GridView`: Tabela com busca em tempo real, ordenação por cabeçalho, paginação e paginação infinita.
* `FormView`: Formulário de cadastro/edição com máscaras e validação instantânea.
* `DetailView`: Ficha detalhada do registro selecionado com botões de ação e abas de relacionamentos.
* `KanbanView`: Quadro Kanban por colunas baseado em um campo `EnumField`.

### Posicionamento no Menu (`position`)
* `position="primary"`: Fica visível na barra de navegação principal superior ou lateral.
* `position="menu"`: Disponível dentro do menu expansível do app.
* `position="ref"`: Não aparece no menu; só é acessada por drill-down (ex: clicar num registro da grid abre a DetailView).

```python
from ridel.core.views import DetailView, FormView, GridView, KanbanView

pedidos_grid = GridView(
    name="pedidos_grid",
    label="Lista de Pedidos",
    table="pedidos",
    position="primary",
    columns=["id", "cliente_id", "valor_total", "status"],
    searchable_columns=["id", "cliente_id.razao_social"],
    default_sort={"field": "id", "order": "desc"}
)

pedidos_kanban = KanbanView(
    name="pedidos_kanban",
    label="Kanban de Pedidos",
    table="pedidos",
    group_by_field="status",
    position="menu"
)
```

---

## 🛡️ 4. Controle de Acesso e Perfis (`roles.py`)

O Ridel adota o modelo **RBAC (Role-Based Access Control)** granular por tenant com tipagem estática baseada em `StrEnum`.

### 4.1 Declaração Canônica de Roles (`roles.py`)

Cada tenant declara os papéis de acesso disponíveis como membros de um enum herdando de `enum.StrEnum`:

```python
from enum import StrEnum


class Role(StrEnum):
    """Papéis canônicos de acesso disponíveis no tenant."""

    ADMIN = "admin"
    VENDEDOR = "vendedor"
    OPERADOR = "operador"
    VIEWER = "viewer"
```

> 💡 **Superusuário:** O papel `admin` possui privilégios de superusuário implícitos na plataforma, garantindo acesso irrestrito de leitura, escrita e execução em todas as tabelas e ações.

### 4.2 Matriz de Permissões nas Tabelas (`tables.py`)

Em vez de centralizar regras de acesso em um único arquivo, cada entidade declara seus privilégios CRUD granulares diretamente na classe da tabela usando `TablePermissions` ou dicionários tipados:

```python
from ridel.core.declarative import Table, TablePermissions, TextField
from .roles import Role

STANDARD_PERMISSIONS = {
    Role.ADMIN: TablePermissions(read=True, add=True, edit=True, delete=True),
    Role.VENDEDOR: TablePermissions(read=True, add=True, edit=True, delete=False),
    Role.VIEWER: TablePermissions(read=True, add=False, edit=False, delete=False),
}

class PedidoTable(Table):
    table_name = "pedidos"
    permissions = STANDARD_PERMISSIONS

    # Para casos simples, também é possível usar allowed_roles:
    # allowed_roles = [Role.ADMIN, Role.VENDEDOR]
```

### 4.3 Restrição em Telas (`views.py`) e Ações (`actions.py`)

* **Nas Telas (`views.py`):** Utilize o atributo `allowed_roles` para restringir a visibilidade de uma view:
  ```python
  TableView(
      name="pedidos_list",
      table=PedidoTable,
      allowed_roles=[Role.ADMIN, Role.VENDEDOR],
  )
  ```
* **Nas Ações de Negócio (`actions.py`):** Utilize o parâmetro `roles` no decorador `@action`:
  ```python
  @action(
      name="aprovar_pedido",
      label="Aprovar Pedido",
      table="pedidos",
      roles=[Role.ADMIN],
  )
  ```

---

## ⚡ 5. Regras de Negócio e Ações (`actions.py`)

Use o decorator `@action` para criar botões que disparam regras de negócio diretamente na interface do usuário:

```python
from ridel.core.actions import ActionContext, action
from ridel.core.icons import Icons

@action(
    name="aprovar_pedido",
    label="Aprovar Pedido",
    table="pedidos",
    icon=Icons.CHECK_CIRCLE,
    color="#4CAF50",
    roles=["admin", "gerente"],
    visible_when="record.status == 'pendente'",
)
async def aprovar_pedido(record: dict, ctx: ActionContext) -> dict:
    """Muta o status do pedido para aprovado atomicamente."""
    # O Ridel garante transação segura e contexto do usuário autenticado (ctx.user_id)
    return {
        "status": "aprovado",
        "aprovado_por": ctx.user_id,
        "message": f"Pedido #{record['id']} aprovado com sucesso!"
    }
```

---

## 🚀 6. Menus e Aplicação (`app.py`)

O arquivo `app.py` centraliza a navegação e ícones do tenant:

```python
from ridel.core.app import App, MenuItem
from ridel.core.icons import Icons

vendas_app = App(
    name="vendas",
    title="Gestão de Vendas",
    icon=Icons.SHOPPING_CART,
    menu=[
        MenuItem(label="Pedidos", view="pedidos_grid", icon=Icons.RECEIPT),
        MenuItem(label="Quadro Kanban", view="pedidos_kanban", icon=Icons.VIEW_KANBAN),
    ]
)
```

---

## 👤 7. Usuários e Acessos (`user.py`)

Em `user.py`, declare a lista canônica `users` de usuários locais do tenant utilizando `UserDefinition`. O campo `roles` aceita múltiplos perfis simultâneos (`list[Role | str]`):

```python
from ridel.core.users import UserDefinition
from .roles import Role

users = [
    UserDefinition(
        name="Administrador do Sistema",
        email="admin@empresa.com",
        password="admin123",
        roles=[Role.ADMIN],
        is_active=True,
    ),
    UserDefinition(
        name="Carlos Vendedor",
        email="vendedor@empresa.com",
        password="senha_segura",
        roles=[Role.VENDEDOR, Role.VIEWER],
        is_active=True,
    ),
]
```

> 💡 **Multi-Role & União Inclusiva:** Se um usuário possuir múltiplos papéis (ex.: `[Role.VENDEDOR, Role.VIEWER]`), o Ridel concede acesso se **qualquer uma** de suas roles for autorizada para a tabela, tela ou ação solicitada.

---

## 🔧 8. Ciclo de Desenvolvimento e CLI Ridel

Trabalhar com a Plataforma Ridel no contêiner é instantâneo:

### 8.1 Criar um Novo Tenant em 1 Segundo
```bash
docker exec -it ridel ridel create-tenant nome_do_cliente
```
Isso gera a pasta estruturada com todos os arquivos modelo em `/data/tenants/nome_do_cliente/`.

### 8.2 Validar seu Código com o Checker Estático
Antes de abrir a tela, rode o validador:
```bash
docker exec -it ridel ridel check nome_do_cliente
```
O linter inspeciona toda a AST do Python, detecta erros de digitação de colunas, ciclos em views e permissões inválidas.

### 8.3 Hot-Metadata Refresh (Sem Reiniciar Nada!)
1. Abra o arquivo `tables.py`, `views.py` ou `actions.py` no VS Code da sua máquina (lembre-se que `/data/tenants` está montada no seu disco).
2. Salve as alterações.
3. Abra a janela do navegador no Ridel e clique no botão **"Atualizar Dados"** na barra superior (TopBar).
4. O Universal Player Flutter Web lê as novas definições na hora: **sem F5, sem recompilar o frontend e sem reiniciar o contêiner**.
