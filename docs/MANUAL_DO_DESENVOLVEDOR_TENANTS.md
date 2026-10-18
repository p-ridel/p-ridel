# Manual Oficial do Desenvolvedor de Tenants — Plataforma Ridel

Bem-vindo ao **Manual do Desenvolvedor da Plataforma Ridel**. 

O Ridel foi projetado sob a premissa de **Spec-Driven e Declarative Development**: a Engine (Backend FastAPI e Frontend Universal Player Flutter) é fornecida como um contêiner imutável. Como desenvolvedor, **você não precisa alterar código do core, nem escrever HTML/CSS/Flutter, nem gerenciar migrações manuais de SQL**. Toda a sua aplicação é construída declarando entidades, regras e fluxos em Python dentro da pasta de tenants.

---

## 📁 1. Estrutura de Diretórios de um Tenant

Cada sistema ou cliente da plataforma reside como um subdiretório dentro de `/data/tenants/`:

```text
/data/tenants/<nome_do_tenant>/
├── __init__.py           # Identificador do pacote Python
├── apps/                 # Diretório obrigatório contendo os aplicativos do tenant
│   ├── __init__.py
│   ├── principal.py      # Aplicação principal
│   └── financeiro.py     # Outras aplicações/módulos do tenant
├── tables.py             # Modelagem declarativa de dados, campos e enums
├── views.py              # Declaração das telas (Grids, Forms, Kanbans, Detalhes)
├── roles.py              # Perfis de acesso, permissões CRUD e RBAC
├── row_actions.py        # Ações a nível de linha/seleção múltipla com @action
├── table_actions.py      # Ações a nível de tabela com @table_action e table.filter(...)
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
* `PrivateTextField(name, label, required=False)`: Textos protegidos para segredos/tokens que são automaticamente omitidos de respostas da API e bloqueados contra escrita não autorizada.

### Campos Privados e Segredos (`PrivateTextField` / `is_private=True`)
Para campos que contêm dados altamente sensíveis (como credenciais, segredos criptográficos ou chaves de API internas), use `PrivateTextField` ou o parâmetro `is_private=True`. O motor do CRUD da plataforma garante soberanamente:
1. **Omissão total na API:** Esses campos nunca são serializados em consultas (`GET` / listagens / detalhes).
2. **Proteção contra mutação externa:** Tentativas de gravar ou atualizar esses campos via rotas genéricas de CRUD retornam `HTTP 403 Forbidden`.

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

### Inspeção Visual com Machine Learning (`MachineQualityField`)
A plataforma Ridel oferece visão computacional e Machine Learning 100% local, em tempo real (< 50ms) e sem custos de API:

* **`MachineQualityField`**: Campo de inspeção visual na tabela operacional (ex: `InspecaoTable`). Conduz a captura da câmera ou upload, projeta a silhueta HUD orientativa em ciano, executa a inferência neural local via MobileNetV3 ONNX + Prototype Centering e registra a auditoria ISO 9001 (com obrigatoriedade de justificativa $\ge 10$ caracteres em caso de sobrescrita humana).

#### Parametrização Dinâmica e Declarativa (Poka-Yoke):
O desenvolvedor pode calibrar a sensibilidade da inspeção diretamente no código Python através de `threshold` (confiança mínima percentual) e `temperature` (fator de escala angular Softmax para separação extrema de defeitos sutis), tendo precedência declarativa sobre as configurações do banco. Além disso, o operador na ponta nunca escolhe modelos de IA: o gestor vincula diretamente no **Estúdio de Machine Learning** qual modelo atende a cada tabela e coluna (`target_table` e `target_field`), e a plataforma resolve a vinculação automaticamente:

```python
from ridel.core.declarative import (
    ForeignKeyField,
    MachineQualityField,
    Table,
    TextField,
)

class InspecaoTable(Table):
    table_name = "inspecoes"

    identificador = TextField(label="Identificador", required=True)
    # Vinculado dinamicamente pelo usuário no Estúdio de Machine Learning:
    resultado = MachineQualityField(
        label="Inspeção Visual",
        threshold=0.85,      # Confiança mínima (0.85 = 85%) para status confiável
        temperature=0.04,    # Calibração angular Softmax para discriminação fina
    )
```

#### Máscara Estrita de Silhueta HUD:
Durante o enquadramento na câmera/modal de ajuste (`InspectionAlignmentDialog`), o operador alinha a peça na silhueta. Ao confirmar, o motor aplica algoritmo BFS Flood-Fill a partir das bordas externas, mascarando 100% do fundo externo (bancada, mãos do operador, ruídos) antes do envio para o MobileNetV3 ONNX, garantindo predições invariantes a iluminação de ambiente e bancadas de teste.

---

## 🖥️ 3. Interfaces e Telas (`views.py`)

No `views.py`, você define como os dados serão exibidos no **Universal Player Flutter Web**:

### Tipos de Views Disponíveis
* `TableView`: Tabela com busca em tempo real, ordenação por cabeçalho, paginação infinita, filtros e agrupamento hierárquico.
* `DeckView`: Visualização em cartões ("decks") responsivos inspirada no AppSheet, com imagem/avatar à esquerda, cabeçalho principal, secundário, sumário no canto direito, dois campos extras com divisor vertical e barra inferior de ações operacionais.
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

### Agrupamento Declarativo em TableView (`group_by`) e Multi-Agrupamento Hierárquico

Você pode adicionar agrupamento em árvore (inclusive **multi-nível hierárquico em cascata**) com cálculo automático de agregadores no backend em qualquer `TableView` utilizando `GroupByConfig`, `SortOrder` e `Aggregators`:

```python
from ridel.core.declarative import (
    AggregatorConfig,
    Aggregators,
    GroupByConfig,
    SortOrder,
    TableView,
)
from .tables import CustomerTable

customers_list = TableView(
    name="customers_list",
    table=CustomerTable,
    title="Clientes",
    fields=[
        CustomerTable.name,
        CustomerTable.client_type,
        CustomerTable.pais,
        CustomerTable.email,
    ],
    group_by=[
        # Nível 1: Agrupar por País
        GroupByConfig(
            field=CustomerTable.pais,
            order=SortOrder.ASC,
            aggregators=[
                AggregatorConfig(label="Total de Clientes", function=Aggregators.COUNT()),
            ],
        ),
        # Nível 2: Sub-agrupar por Tipo de Cliente (PF/PJ)
        GroupByConfig(
            field=CustomerTable.client_type,
            order=SortOrder.ASC,
            aggregators=[
                AggregatorConfig(label="Quantidade", function=Aggregators.COUNT()),
            ],
        ),
    ],
)
```

* **Ordenação autocompletável (`SortOrder`):** Use `SortOrder.ASC` ou `SortOrder.DESC` para garantia estática de tipos no IDE.
* **Agregadores declarativos (`Aggregators`):**
  * `Aggregators.COUNT()`: Conta registros do nó.
  * `Aggregators.SUM(Table.field)`: Soma valores numéricos do campo.
  * `Aggregators.AVG(Table.field)`: Média aritmética dos valores do campo.
  * `Aggregators.MIN(Table.field)` / `Aggregators.MAX(Table.field)`: Valores mínimo e máximo.
  * Fórmulas personalizadas Python / callables: `function=lambda records: sum(r.get('total', 0) for r in records)`.
  * *Eliminação do parâmetro `field` legado em `AggregatorConfig`:* O resultado renderizado na interface é diretamente o valor avaliado pela fórmula/helper em `function`.
* **Painel Lateral Automático (`GroupByPanel`):** No Universal Player Flutter, um painel lateral em árvore recursiva renderiza o nó "Todos", nós expansíveis por nível hierárquico com badges de agregadores, persistência do nó selecionado no `localStorage`/`SharedPreferences` e filtragem reativa e imediata dos registros na tabela.

### Visualização em Cartões DeckView (Padrão AppSheet)

A `DeckView` exibe os registros em cartões organizados e responsivos ("decks"), inspirada no padrão Deck View do Google AppSheet e perfeitamente integrada à identidade visual minimalista da Plataforma Ridel.

#### 🎴 Anatomia e Regras Visuais do DeckCard:
* **Área da Esquerda (Imagem / Avatar):**
  * Container quadrado com cantos arredondados (`BorderRadius.circular(8)`).
  * **Omissão total:** Quando o desenvolvedor não configura o campo `image` (`image=None`), a área de imagem é **completamente omitida** (largura zero, sem avatar e sem iniciais), permitindo que a área textual utilize 100% da largura do card.
  * Quando o campo `image` estiver configurado na view:
    * Se o registro possuir mídia/foto, exibe a imagem via rede com tratamento de erro e loading.
    * Se o registro específico não tiver foto (nulo/vazio), exibe automaticamente o fallback com as **iniciais de 2 caracteres** e cor sutil gerada deterministicamente por hash do ID/label.
* **Título Principal:** Exibido com suporte a até 2 linhas com reticências (`maxLines: 2, TextOverflow.ellipsis`), mantendo a altura homogênea e padronizada de todos os cards da grade responsiva.
* **Título Secundário:** Subtítulo com cor atenuada (`onSurfaceVariant`) abaixo do título principal (`maxLines: 1`).
* **Sumário:** Canto superior direito alinhado à direita no card, formatado pelo tipo de dado. Valores monetários (`type="currency"`) exibem sempre o prefixo oficial brasileiro `"R$ "` (ex: `"R$ 1.500,00"`).
* **Campos Extras:** Suporte a até 4 campos extras (`extra_field_1`, `extra_field_2`, `extra_field_3`, `extra_field_4`) dispostos horizontalmente em **1 única linha**, em colunas proporcionais separadas visualmente por divisores verticais sutis (`VerticalDivider`), exibindo mini-rótulo e valor tipado.
* **Barra de Ações Inferior:** 
  * Separada por uma suave linha divisória.
  * **Alinhamento à Direita:** Os botões de ação são alinhados à direita do card (`MainAxisAlignment.end`).
  * **Visibilidade e Habilitação Condicional:** A renderização respeita dinamicamente as regras declarativas `visible_when` e `enabled_when` de cada ação avaliadas individualmente no contexto do registro atual e da sessão do usuário autenticado.
  * Comporta até 3 botões de ação diretos e agrupa ações excedentes em um menu de três pontos (`...` / `PopupMenuButton`).
  * **Omissão total:** O desenvolvedor deve declarar explicitamente as ações desejadas em `actions=[...]`. Caso não declare ações ou nenhuma ação esteja visível para o registro, a barra inferior e a linha divisória são omitidas por completo para manter o layout limpo e minimalista.
* **Preservação de Posição/Scroll:** A execução de ações contextuais de linha atualiza o registro modificado pontualmente em memória, sem resetar a lista e sem rolar a tela para o topo.
* **Navegação e Seleção:** 
  * No modo padrão, tocar em qualquer área do card abre a `DetailView` do registro.
  * No modo de seleção múltipla (ações em lote), o toque no card alterna a seleção do checkbox e suspende a navegação.
* **Paridade Total com TableView:** Filtros por coluna, busca em tempo real, ordenação por cabeçalho, ações em lote (`bulk_actions`) e agrupamento hierárquico reativo com agregadores (`group_by`).

#### Exemplo de Declaração de `DeckView` (`views.py`):

```python
from ridel.core.declarative import (
    AggregatorConfig,
    Aggregators,
    DeckView,
    GroupByConfig,
    Icons,
    SortOrder,
    ViewPosition,
)
from .roles import Role
from .tables import ServiceOrderTable

service_orders_deck = DeckView(
    name="service_orders_deck",
    table=ServiceOrderTable,
    title="Painel Deck de OSs",
    icon=Icons.DASHBOARD,
    position=ViewPosition.PRIMARY,
    allowed_roles=[Role.ADMIN, Role.OPERATOR, Role.VIEWER],
    default_sort="created_at DESC",
    # Mapeamento dos campos estruturais do Deck:
    image=None,  # Área omitida completamente se None; ou ServiceOrderTable.foto para exibir com fallback
    primary_header=ServiceOrderTable.order_code,
    secondary_header=ServiceOrderTable.defect_description,
    summary=ServiceOrderTable.total_amount,  # Exibido como "R$ 1.500,00"
    extra_field_1=ServiceOrderTable.status,
    extra_field_2=ServiceOrderTable.customer_id,
    extra_field_3=ServiceOrderTable.created_at,
    extra_field_4=ServiceOrderTable.cancellation_reason,
    # Ações permitidas na barra inferior do deck (respeitam visible_when e enabled_when individualmente):
    actions=[
        "start_progress",
        "complete_order",
        "cancel_order",
        "reopen_order",
    ],
    # Agrupamento declarativo completo:
    group_by=[
        GroupByConfig(
            field=ServiceOrderTable.status,
            order=SortOrder.ASC,
            aggregators=[
                AggregatorConfig(label="Quantidade", function=Aggregators.COUNT()),
                AggregatorConfig(
                    label="Total (R$)",
                    function=Aggregators.SUM(ServiceOrderTable.total_amount),
                ),
            ],
        )
    ],
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

### 4.4 Filtros de Segurança a Nível de Linha (`security_filter` / Row-Level Security)

Enquanto `permissions` controla o acesso às operações CRUD na tabela como um todo, o **`security_filter`** restringe **quais linhas** do banco de dados o usuário autenticado pode acessar, visualizar, editar, deletar ou executar ações (equivalente funcional aos *Security Filters* do Google AppSheet).

O filtro é compilado diretamente para a cláusula SQL `WHERE` nativa do PostgreSQL, garantindo que registros restritos sequer trafeguem pela rede:

```python
from ridel.core.declarative import Table, TextField
from ridel.core import session
from .roles import Role

class LeadTable(Table):
    table_name = "leads"
    record_label = "title"

    title = TextField(label="Título", required=True)
    vendedor_id = TextField(label="Vendedor ID", required=True)
    status = TextField(label="Status")

    # Vendedores só acessam seus próprios leads; Administradores acessam tudo
    security_filter = (vendedor_id == session.user_id) | session.has_role(Role.ADMIN)
```

#### Características Essenciais do `security_filter`:
1. **Ocultamento e Zero Trust**: Registros fora do filtro são ignorados na listagem, busca global e agregação (`group-by`).
2. **Proteção de IDs (`HTTP 404`)**: Se um usuário tentar abrir, editar ou executar uma ação em um registro fora do seu escopo informando diretamente o UUID, o sistema retorna estritamente `HTTP 404 Not Found` (não revelando sequer a existência do registro).
3. **Validação no INSERT (`HTTP 422`)**: Na criação de um novo registro, o backend avalia ativamente o payload contra o `security_filter` do autor. Se o autor tentar forjar a autoria ou criar um registro que violaria seu próprio filtro, a API bloqueia com `HTTP 422 Unprocessable Content`.
4. **Verificação Estática (`ridel check`)**: O linter offline valida colunas, roles declaradas e conformidade da expressão em milissegundos, com sugestões de correção via `difflib`.

---

## ⚡ 5. Regras de Negócio e Ações (`row_actions.py` e `table_actions.py`)

A plataforma organiza as ações de negócio de forma declarativa e modular em dois arquivos especializados:

### 5.1 Ações a Nível de Linha (`row_actions.py`)
Utilize o decorador `@action` para ações que operam sobre um registro individual (na tela de detalhes ou na seleção múltipla de linhas):

```python
from ridel.core.declarative import action, ActionInput, ActionInputs, Icons
from .roles import Role
from .tables import ServiceOrderTable, OrderStatus

@action(
    name="complete_order",
    label="Concluir OS",
    table=ServiceOrderTable,
    icon=Icons.CHECK_CIRCLE,
    allowed_roles=[Role.ADMIN, Role.OPERATOR],
    requires_confirmation=True,
    confirmation_message="Deseja realmente concluir esta Ordem de Serviço?",
    visible_when=(ServiceOrderTable.status == OrderStatus.EM_ATENDIMENTO),
)
def complete_order_action(record, ctx):
    record.status = OrderStatus.CONCLUIDA
```

### 5.2 Ações a Nível de Tabela (`table_actions.py`)
Utilize o decorador `@table_action` para rotinas que operam sobre todo o conjunto de registros da tabela (ex: reabertura em massa, limpezas, arquivamento). O handler recebe um helper fluente `table` com métodos de alta produtividade:

```python
from ridel.core.declarative import table_action, Icons
from .roles import Role
from .tables import ServiceOrderTable, OrderStatus

@table_action(
    name="reopen_all_cancelled",
    label="Reabrir Canceladas",
    table=ServiceOrderTable,
    icon=Icons.REFRESH,
    requires_confirmation=True,
    confirmation_message="Deseja realmente reabrir todas as OS canceladas?",
    allowed_roles=[Role.ADMIN, Role.OPERATOR],
)
def reopen_all_cancelled_action(table, ctx, inputs, session):
    # Helper fluente exclusivo do Ridel:
    table.filter(ServiceOrderTable.status == OrderStatus.CANCELADA).update(
        status=OrderStatus.ABERTA
    )
```

#### Métodos do `TableQueryHelper` (`table.filter(...)`):
* `table.filter(*expressions)`: Constrói cláusulas de filtro baseadas nos campos declarativos tipados da tabela.
* `.update(**values)`: Aplica atualização atômica e transacional no PostgreSQL preenchendo automaticamente `updated_at` e `updated_by`. Retorna a quantidade de registros afetados.
* `.delete()`: Executa exclusão dos registros filtrados com soft-delete seguro (`is_deleted=True`, `deleted_at=now`).
* `.all()`: Retorna os registros correspondentes.
* Parâmetro `session`: Fornece a conexão transacional ativa caso o desenvolvedor precise de queries SQLAlchemy complexas.

> [!TIP]
> **Resolução Automática em Tenants Multi-App:** Em tenants com múltiplos apps (`apps/*.py`), as actions podem ser registradas explicitamente nas listas `actions=[...]` e `table_actions=[...]` do aplicativo específico ou compartilhadas. O backend do Ridel identifica o app de contexto através do cabeçalho `X-App-ID` (ou query param `app_id`) e possui fallback inteligente em todas as aplicações registradas do tenant. Dessa forma, actions declaradas em qualquer app do tenant que atendam à tabela são resolvidas e executadas sem erros 404.

---

## 🚀 6. Aplicativos e Menus (`apps/*.py`)

As aplicações do tenant residem obrigatoriamente dentro da pasta `apps/` (ex: `apps/principal.py`). Cada arquivo instancia e exporta um objeto `App`:

```python
from ridel.core.declarative import App, Icons
from ..tables import ItemTable
from ..views import views

app = App(
    app_id="vendas_app",
    name="Gestão de Vendas",
    description="Módulo operacional de vendas",
    primary_color="#1E88E5",
    icon=Icons.SHOPPING_CART,
    initial_view="pedidos_grid",
    tables=[ItemTable],
    views=views,
    actions=[],
    machine_learning=[Role.ADMIN],  # Habilita o Estúdio de ML para administradores
)
```

### Estúdio de Machine Learning (`machine_learning`)
Para disponibilizar o item de menu `🧠 Machine Learning` no aplicativo e permitir que usuários treinem modelos de visão computacional:
* `machine_learning=False` (padrão): O módulo de ML permanece desativado no app.
* `machine_learning=True`: O módulo fica visível e liberado para todos os usuários com acesso ao app.
* `machine_learning=[Role.ADMIN, Role.QUALIDADE]`: O módulo e seus endpoints de API são restritos exclusivamente aos perfis informados. O linter `ridel check` valida estaticamente se todos os membros da lista pertencem ao `Role` enum do tenant (`RULE_ML_PERMISSION_VALIDITY`).

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

> 🔒 **Blindagem de Privilégios (RBAC de Usuários):** Para prevenir escalada indevida de privilégios ou travamento de contas por outros usuários, alterações nas colunas `roles` e `is_active` de usuários via API de CRUD são restritas unicamente a administradores (`Role.ADMIN`). Usuários com perfis comuns recebem `HTTP 403 Forbidden` se tentarem alterar estes atributos.

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

### 8.3 LiveSync Reativo de Metadados (Instantâneo e 100% Automático!)
A Plataforma Ridel conta com o **LiveSync Reativo** via Server-Sent Events (SSE). O backend monitora alterações em tempo real na pasta do tenant e notifica imediatamente o Universal Player:

1. Abra o arquivo `tables.py`, `views.py`, `apps.py` ou `actions.py` no seu editor favorito.
2. Salve as alterações.
3. **Pronto!** O Universal Player no navegador detecta a mudança e atualiza a interface instantaneamente (< 300ms):
   - **Sem apertar `r`** no terminal.
   - **Sem recarregar a página (sem F5)** e sem perder o estado de navegação ou filtros ativos.
   - **Sem precisar clicar em "Atualizar Dados"** (embora o botão continue disponível na TopBar como alternativa manual).
   - **Compatível com o Modo Release:** Funciona com velocidade nativa (60fps fluidos) mesmo quando o frontend estiver rodando em `--release` (`ridel frontend release`), pois a sincronização de metadados declarativos não necessita de recompilação Dart.

---

## 👥 9. Contexto da Sessão do Usuário (`session`)

A plataforma Ridel fornece suporte nativo e tipado ao usuário atualmente logado via o proxy `session`. Ele pode ser utilizado diretamente em condições de visibilidade, habilitação, obrigatoriedade de campos, fórmulas persistidas e botões de ação.

### 9.1 Atributos Padronizados de Sessão
Para utilizar em expressões declarativas, importe:
```python
from ridel.core import session
```
Os seguintes atributos canônicos são expostos:
* `session.user_id`: Identificador único do usuário logado (ex: `"1"`).
* `session.roles`: Lista de papéis atribuídos ao usuário (ex: `["admin", "operador"]`).
* `session.email`: E-mail autenticado (ex: `"admin@empresa.com"`).
* `session.name`: Nome completo de exibição do usuário.
* `session.tenant_id`: Identificador do tenant ativo.
* `session.avatar_url`: URL de foto de perfil (quando cadastrada).

### 9.2 Condições Declarativas em Campos (`tables.py`)
Utilize `session.has_role(...)` para verificar permissões de forma declarativa e idiomática:
```python
from ridel.core.declarative import Table, TextField, NumberField
from ridel.core import session
from .roles import Role

class OrdemServicoTable(Table):
    table_name = "ordens_servico"

    # Campo visível na interface APENAS para administradores:
    notas_auditoria = TextField(
        label="Notas da Auditoria",
        multiline=True,
        required=False,
        visible=session.has_role(Role.ADMIN),
    )

    # Campo editável (FLS Write) apenas para quem for admin OU operador:
    solucao_tecnica = TextField(
        label="Solução Técnica",
        editable=session.has_role(Role.ADMIN) | session.has_role(Role.OPERATOR),
    )

    # Campo com confidencialidade absoluta (FLS Read + Write):
    # Bloqueia exibição no frontend e purga da API (null) para usuários não-administradores
    custo_interno = NumberField(
        label="Custo Interno",
        is_currency=True,
        required=False,
        readable=session.has_role(Role.ADMIN),
        editable=session.has_role(Role.ADMIN),
    )
```

> ⚠️ **Atenção (Anti-padrão Proibido):** Nunca escreva `Role.ADMIN in session.roles` dentro de parâmetros declarativos (`visible`, `readable`, `editable`, `required`). O operador `in` nativo do Python exige retorno booleano imediato e quebra a serialização da AST. Use invariavelmente `session.has_role(Role.ADMIN)`. O linter `ridel check` audita essa regra estaticamente (`RULE_SESSION_IN_OPERATOR_ANTI_PATTERN` e `RULE_CLEAN_PARAMS_CANONICAL`).

### 9.3 Autoria em Fórmulas Persistidas (`formula=`)
Nas funções lambda de fórmulas calculadas, o objeto `r.session` está disponível:
```python
class DocumentoTable(Table):
    table_name = "documentos"

    # Preenche o e-mail do autor na criação, sem sobrescrever em edições futuras:
    criado_por = TextField(
        label="Criado por",
        readonly=True,
        formula=lambda r: r.criado_por or r.session.email,
    )
```

### 9.4 Ações de Negócio Condicionais (`actions.py`)
No decorador `@action`, você pode condicionar a visibilidade do botão com base no papel e acessar os dados da sessão via `ctx.session`:
```python
from ridel.core.declarative import action, Icons
from ridel.core import session
from .roles import Role
from .tables import OrdemServicoTable

@action(
    name="escalar_diretoria",
    label="Escalar para Auditoria",
    table=OrdemServicoTable,
    icon=Icons.SECURITY,
    allowed_roles=[Role.ADMIN, Role.OPERATOR],
    visible_when=session.has_role(Role.ADMIN),
    requires_confirmation=True,
    confirmation_message="Deseja registrar solicitação de auditoria pelo administrador?",
)
def escalar_diretoria_action(record, ctx):
    record.obs = f"{record.obs or ''}\n[Auditoria por {ctx.session.get('email', 'admin')}]".strip()
```

### 9.5 Testando no Simulador de Tenants (Universal Player)
No topo da interface do Universal Player Flutter, o **Simulador de Usuários/Tenants** permite alternar instantaneamente entre os perfis cadastrados (`Role.ADMIN`, `Role.OPERATOR`, `Role.VIEWER`, etc.).
Graças à reatividade integrada (`ref.watch(authProvider)`), ao trocar o usuário no simulador a tela reavalia todas as regras de `session` com **0ms de latência**, exibindo ou ocultando campos e botões em tempo real sem necessidade de recarregar o navegador.

---

## 10. Editor Integrado de Tenant via IA (Modo Terminal)

A Plataforma Ridel conta com um **Terminal do Desenvolvedor com IA Integrada** diretamente no Universal Player. Ele permite que desenvolvedores autorizados criem tabelas, views, regras e apps através de instruções em linguagem natural, mantendo o padrão declarativo canônico sem precisar digitar todo o código manualmente.

### 10.1 Como Acessar o Terminal
1. Faça login com um usuário que possua a role `admin` (ex: `admin@demo.com`).
2. Clique no ícone de terminal (`Icons.terminal`) na **TopBar** (ao lado do simulador) ou pressione o atalho de teclado global **`Ctrl + '`** (Ctrl + aspas simples).
3. O painel inferior do terminal será exibido em estilo DevTools/VS Code (altura padrão de 340px).

### 10.2 O Ciclo de Engenharia em 5 Fases
O editor não funciona como um chat genérico ou conversacional; ele segue um ciclo estruturado e rigoroso:

1. **Prompt do Desenvolvedor:**
   Digite o que deseja construir ou modificar:
   ```bash
   ridel-ai@demo:~$ criar tabela de Transportadoras com nome, cnpj, telefone e cidade
   ```
2. **Grill-Me de Alinhamento Técnico:**
   A IA analisa o código existente no seu tenant (`tables.py`, `views.py`, etc.) e formula de 2 a 4 perguntas estruturadas de engenharia sobre relacionamentos, obrigatoriedade de campos e permissões.
3. **Respostas às Perguntas:**
   Responda às perguntas diretamente no prompt do terminal (ex: `1: Sim com FK, 2: obrigatórios`).
4. **Dry-Run e Validação Semântica (Checker):**
   A IA compila o código em memória, executa o linter semântico `ridel check` e exibe o **Diff unificado** colorido (+ verde, - vermelho) com a indicação de conformidade:
   ```text
   ✔ Validação do Checker: SUCESSO (0 erros)
   Diferenças propostas (Diff unificado):
   --- tables.py
   +++ tables.py
   ...
   Deseja comitar e aplicar as alterações no tenant? [Y/n]:
   ```
5. **Commit Atômico e Ponto de Restauração:**
   Digite `y` ou `s` para confirmar. O sistema:
   - Cria um snapshot de backup em `.snapshots/<snapshot_id>`.
   - Grava os arquivos fisicamente em `backend/tenants/<tenant>/`.
   - Registra o comando e as linhas alteradas em `.terminal_history.log`.
   - Dispara a sincronização instantânea do Universal Player, recarregando views e tabelas imediatamente sem necessidade de F5.

### 10.3 Comandos Auxiliares
- `help`: Exibe a lista de comandos e instruções.
- `clear`: Limpa as linhas de saída do terminal.
- `rollback`: Desfaz imediatamente a última alteração comitada, restaurando os arquivos a partir do snapshot.
- `exit`: Fecha o painel do terminal.
- **Setas Cima / Baixo (`↑` / `↓`):** Navega pelo histórico de comandos digitados na sessão.

### 10.4 Confinamento e Segurança Absoluta
- **Isolamento de Tenant:** O motor de IA é fisicamente restrito à pasta do tenant correspondente (`backend/tenants/<seu_tenant>/`). Ele não possui permissão nem capacidade de alterar o core da plataforma Ridel, arquivos de configuração ou outros tenants.
- **Proteção RBAC:** O endpoint da API `/api/v1/{tenant}/dev/ai/*` e a interface do terminal exigem estritamente perfil de administrador (`admin`), respondendo com `HTTP 403 Forbidden` para qualquer outro usuário.

---

## 11. Tenant de Demonstração Canônico (`tenants/demo/`): Vitrine Operacional em Casos Reais

O tenant `demo` da plataforma Ridel foi estruturado como uma vitrine viva de problemas reais de ponta de linha de frente (*edge operations*) que sistemas ERP tradicionais não conseguem resolver. Ele agrega 6 aplicações completas, ilustrando 100% dos componentes ricos e recursos especiais nativos da plataforma.

### 11.1 Catálogo dos 6 Aplicativos Declarativos

| Aplicativo | Ramo de Negócio | Tabela Principal | Recursos de Destaque |
|---|---|---|---|
| **Controle de Qualidade & IA** (`apps/qualidade_manufatura.py`) | Indústria Metalúrgica & Manufatura | `quality_inspections` | **Visão Computacional Local** (`MachineQualityField`) com câmera com HUD em tempo real na bancada de teste (inspeção de caneta com tampa vs. sem tampa), desvios milimétricos, ações de override ISO 9001 e reavaliação em lote (`table_actions`). |
| **Diário de Obra e Fiscalização** (`apps/diario_obra.py`) | Construção Civil & Engenharia | `construction_diaries` | **Geolocalização & GPS** (`LatLongField`, `AddressField`), **Captação de Vídeo** (`VideoField`) com legendas/transcrição automática e **Assinatura Digital** (`SignatureField`) na tela do dispositivo. |
| **Logística & Frota** (`apps/logistica_entregas.py`) | Transporte & Distribuição | `delivery_incidents` | **Transcrição de Áudio Ditado por Voz** (`AudioField`), mapa interativo de localização e canhoto de entrega com assinatura digital. |
| **Manutenção Industrial** (`apps/manutencao_industrial.py`) | Assistência Técnica & Maquinário | `maintenance_orders` | **Diagnóstico Acústico por Vídeo** (`VideoField`), medição de vibração e temperatura, fluxo de estados por `@action` (Aberto -> Diagnóstico -> Aguardando Peças -> Concluída) e assinatura de aceite. |
| **Agronegócio & Safra** (`apps/agronegocio_lavouras.py`) | Agricultura de Precisão | `crop_scoutings` | **Mapeamento de Talhões** (`LatLongField`), registro de folhas/pragas (`ImageField`), **Fórmulas Declarativas** automáticas (`formula=`) calculando sacas perdidas e **Agrupamento Hierárquico Multi-Nível** (`GroupByConfig`). |
| **Auditoria SST & Compliance** (`apps/auditoria_sst.py`) | Segurança do Trabalho | `safety_audits` | **Evidência Fotográfica de EPIs** (`ImageField`), **Entrevista DDS Gravada em Áudio** (`AudioField`) e **Dupla Assinatura Digital** (Auditor SST e Encarregado da Fábrica). |

### 11.2 Governança de Acesso e Credenciais de Demonstração
Cada aplicação conta com perfis dedicados no `backend/tenants/demo/roles.py` e contas pré-configuradas no `backend/tenants/demo/user.py`:
- `admin@demo.com` (`admin`): Visão global e acesso irrestrito a todos os 6 aplicativos.
- `inspetor@demo.com` (`inspetor_qualidade`): Acesso ao Controle de Qualidade & IA.
- `engenheiro@demo.com` (`engenheiro_obra`): Acesso ao Diário de Obra.
- `motorista@demo.com` (`motorista_logistica`): Acesso à Logística & Entregas.
- `tecnico@demo.com` (`tecnico_manutencao`): Acesso à Manutenção Industrial.
- `agronomo@demo.com` (`agronomo_campo`): Acesso ao Agronegócio & Safra.
- `auditor@demo.com` (`auditor_sst`): Acesso à Auditoria de SST.
*(Senha padrão para todos os usuários de teste: `demo123` / `admin123` para o administrador).*

### 11.3 Inicialização sob Demanda e Idempotência
Os dados de demonstração utilizam a rotina canônica `backend/tenants/demo/seed.py`:
- **Sem mutações indesejadas no boot:** O backend nunca roda seed automaticamente na inicialização, preservando o estado do banco.
- **Idempotência estrita com UPSERT:** O comando `ridel seed demo` utiliza chaves determinísticas UUIDv5 baseadas no tenant e no identificador de negócio, garantindo que execuções repetidas nunca gerem registros duplicados.

### 11.4 Navegação Multi-View, DeckViews e Slices Operacionais
Todos os 6 aplicativos do tenant demo implementam o padrão multi-view da plataforma Ridel, combinando visualizações complementares acessíveis pela barra de navegação e menu:

1. **TableView (`position=ViewPosition.PRIMARY`):** Grade tabular densa para auditoria, ordenação e visualização global de registros.
2. **DeckView (`position=ViewPosition.PRIMARY`):** Mural responsivo de cartões ricos (estilo AppSheet) destacando evidências visuais (`image`), cabeçalhos primários/secundários e agrupamento hierárquico (`group_by`).
3. **SliceView com Slice Operacional (`position=ViewPosition.PRIMARY`):** Visualizações especializadas conectadas a fatias de dados (`Slice`), permitindo foco imediato em registros críticos:

| Aplicativo | DeckView | Slice Operacional | SliceView Dedicada |
|---|---|---|---|
| **Controle de Qualidade & IA** | `quality_inspections_deck` | `lotes_reprovados_slice` | `quality_inspections_reprovadas_view` (Lotes Inconformes) |
| **Diário de Obra** | `construction_diaries_deck` | `diarios_com_chuva_slice` | `construction_diaries_chuva_view` (Paralisações por Chuva) |
| **Logística & Frotas** | `delivery_incidents_deck` | `entregas_em_rota_slice` | `delivery_incidents_em_rota_view` (Cargas em Trânsito) |
| **Manutenção Industrial** | `maintenance_orders_deck` | `manutencoes_ativas_slice` | `maintenance_orders_ativas_view` (O.S. em Andamento) |
| **Agronegócio & Safra** | `crop_scoutings_deck` | `talhoes_criticos_slice` | `crop_scoutings_criticos_view` (Infestação Crítica) |
| **Auditoria SST** | `safety_audits_deck` | `auditorias_interditadas_slice` | `safety_audits_interditadas_view` (Postos Interditados) |

### 11.5 Campos Booleanos e Expressões Condicionais Reativas
Cada aplicativo do tenant demo demonstra o poder das expressões AST declarativas associadas a campos booleanos (`BooleanField`), controlando visibilidade (`visible=`) e obrigatoriedade (`required=`) sem escrever uma única linha de JavaScript:

- **Controle de Qualidade:** `reinspecao_obrigatoria` (`BooleanField`) torna `motivo_reinspecao` visível e obrigatório, além de liberar o campo `prazo_reinspecao_horas`.
- **Diário de Obra:** `houve_chuva` (`BooleanField`) torna `precipitacao_milimetros` visível e obrigatório, além de exibir `horas_paralisadas_chuva`.
- **Logística & Frotas:** `houve_avaria_carga` (`BooleanField`) torna `descricao_avaria` visível e obrigatório, além de exibir `valor_prejuizo_estimado` formatado em moeda (R$).
- **Manutenção Industrial:** `parada_emergencial` (`BooleanField`) torna `tempo_parada_minutos` visível e obrigatório; `requer_terceirizado` (`BooleanField`) exige a indicação da `empresa_terceirizada`.
- **Agronegócio:** `necessita_reaplicacao` (`BooleanField`) torna `defensivo_recomendado` visível e obrigatório, acompanhado do prazo em dias.
- **Auditoria SST:** `interdicao_setor` (`BooleanField`) torna `motivo_interdicao` visível e obrigatório, acompanhado da previsão de desinterdição.

