# Pré-execução: pipeline medalhão Bakehouse → dashboard AI/BI

Levantamento feito em 2026-11-24, antes de qualquer criação de recurso.

**Prompt oficial:** `Prompt v2 aula databricks claude code.md` (vault do Obsidian), idêntico ao bloco "Prompt completo" de `databricks_claude_code_v1/APRENDIZADO/prompt-build-medalhao.md`.

## Situação dos catálogos

Verificação feita com `--profile portfolio-free`, usuário `alencardoug@gmail.com`:

| Catálogo | Situação |
|---|---|
| `bakehouse_dev` | **Não existe** (`Catalog 'bakehouse_dev' does not exist`) |
| `bakehouse_prod` | **Não existe** |
| Existentes no workspace | só `workspace`, `system` e `samples` |

Na primeira rodada, o prompt mandava parar nesse caso, e a execução parou: nada foi criado. O prompt foi revisado e agora **autoriza a criação pontual** dos dois catálogos (ver "Fase 0.5"). Nenhum outro catálogo (`workspace`, `main`) será usado como alternativa.

## Fase 0.5: criação pontual dos catálogos (fora do bundle)

Feita uma única vez, como ação de administração. O comando roda de forma avulsa no SQL warehouse e não fica gravado em nenhum arquivo do projeto.

1. Confirmar o privilégio `CREATE CATALOG` no metastore. Se não houver, **parar**.
2. Mostrar o SQL exato antes de executar:
   ```sql
   CREATE CATALOG IF NOT EXISTS <nome>
     COMMENT 'Ambiente <dev|prod> da Bakehouse. Gerenciado fora do bundle.';
   ```
   Usar o armazenamento padrão do metastore. Se ele exigir `MANAGED LOCATION`, **parar e perguntar**.
3. Criar só `bakehouse_dev` e `bakehouse_prod`. Nunca usar DROP nem recriar.
4. Grants mínimos:
   - `bakehouse_prod`: apenas `USE CATALOG` e `CREATE SCHEMA` para o service principal da esteira (`service_cicd`). **O application ID precisa ser informado pelo usuário, não deduzido.** Sem ele, o catálogo é criado sem o grant e isso fica como pendência.
   - `bakehouse_dev`: nenhum grant extra, porque o usuário fica como owner.
5. Conferir com `databricks catalogs get <nome>` e `databricks grants get catalog <nome>`.

Diferença em relação à aula: lá, o `service_cicd` recebeu **ALL PRIVILEGES** no catálogo `workspace`. Aqui ele recebe só o mínimo, e só no catálogo de prod.

### Resultado (2026-11-24) ✅

- **Passo 1:** o usuário está no grupo `admins`, e o grupo de admins do workspace tem `CREATE_CATALOG` no metastore `metastore_aws_us_east_2`.
- **Passos 2 e 3:** os dois `CREATE CATALOG IF NOT EXISTS ... COMMENT ...` terminaram com `SUCCEEDED`, sem exigir `MANAGED LOCATION` (o workspace usa Default Storage).
- **Passo 5:** os dois catálogos são `MANAGED_CATALOG`, com owner `alencardoug@gmail.com` e sem grants explícitos. Cada um tem só `default` e `information_schema`, criados automaticamente pelo Unity Catalog.
- **Pendente:** o grant do `service_cicd` em `bakehouse_prod`, que fica a cargo do usuário.

## Fase 0: o que já foi verificado

- **CLI:** Databricks CLI v1.26.0.
- **Profiles:** `DEFAULT` e `portfolio-free` apontam para o mesmo host, então todos os comandos usam `--profile portfolio-free`.
- **Warehouse:** existe só o `Serverless Starter Warehouse` (`2efcbc5e1d8fd6e6`). O ambiente parece ser Databricks Free Edition.
- **Fonte `samples.bakehouse`:** lida sem problemas. Colunas:

| Tabela | Colunas |
|---|---|
| `sales_transactions` | transactionID, customerID, franchiseID, dateTime (timestamp), product, quantity, unitPrice, totalPrice (bigint), paymentMethod, cardNumber |
| `sales_franchises` | franchiseID, name, city, district, zipcode, country, size, longitude, latitude, supplierID |
| `sales_customers` | customerID, first_name, last_name, email_address, phone_number, address, city, state, country, continent, postal_zip_code, gender |
| `sales_suppliers` | supplierID, name, ingredient, continent, city, district, size, longitude, latitude, approved |
| `media_customer_reviews` | review, franchiseID, review_date (timestamp), new_id |

### Números de referência, usados para conferir o dashboard

| Métrica | Valor na fonte |
|---|---|
| Transações (= pedidos) | 3.333, todas com `transactionID` único |
| Receita total | 66.471 |
| Ticket médio | 19,94 |
| Franquias / países | 48 / 9, todas com vendas |
| Clientes / fornecedores / reviews | 300 / 27 / 204 |
| Produtos / meios de pagamento | 6 / 3 (amex 1.106, mastercard 1.144, visa 1.083) |
| Órfãos (transação sem cliente ou franquia; review sem franquia) | 0 |
| `totalPrice ≠ quantity × unitPrice` | 0 |
| Período das vendas | 2024-05-01 a 2024-05-17 |
| Período dos reviews | 2024-05-20 a 2024-05-31 |

Países das franquias: Japan 20, US 16, Australia 6, e 1 em cada um destes: Sweden, Canada, Netherlands, Italy, France, Germany.
Países dos clientes: Australia 108, USA 99, Japan 93.

## Fase 1: estrutura do bundle

```
databricks.yml                         # variables.catalog, targets dev/prod, experimental.skip_name_prefix_for_schema
resources/
  schemas.yml                          # bronze, silver, gold (catalog_name: ${var.catalog})
  bakehouse.pipeline.yml               # serverless, catalog/schema + configuration
  bakehouse.job.yml                    # pipeline_task
  bakehouse.dashboard.yml              # dataset_catalog/dataset_schema
src/pipelines/bakehouse/transformations/
  bronze/{transactions,franchises,customers,suppliers,reviews}.sql
  silver/{customers,franchises,transactions,reviews_sentiment}.sql
  gold/{daily_sales_by_franchise,sales_by_product,franchise_performance,
        sales_by_country,top_customers,sentiment_by_franchise}.sql
src/dashboards/bakehouse.lvdash.json
.gitignore                             # .databricks/, etc.
```

A pipeline e o dashboard referenciam os schemas como `${resources.schemas.<camada>.name}`. Com isso o bundle cria os schemas antes da pipeline por dependência, e o nome fica definido num lugar só.

## Fase 2: bronze

São 5 tabelas, cópia fiel da fonte, com `_ingested_at` (`current_timestamp()`) e `_source_table`. Como a fonte é tabela e não arquivo, não existe `_metadata` para usar. Vou testar se `STREAM(samples.bakehouse.*)` funciona, para usar streaming tables. Se o catálogo `samples` não aceitar leitura em streaming, uso materialized views.

## Fase 3: silver

- **`franchises` e `customers`:** país padronizado com um mapa explícito. `US` e `USA` viram um único valor canônico.
- **`transactions`:** tipos corrigidos, `sale_date`, `sale_month`, dia da semana e hora, enriquecida com franquia (cidade, país, lat/long) e cliente.
- **Expectations:**
  - `DROP` para regras críticas: chaves não nulas, `quantity > 0`, `totalPrice = quantity*unitPrice`.
  - `WARN` para regras de domínio: `paymentMethod IN (...)`, coordenadas válidas.
- **`reviews_sentiment`:** `ai_analyze_sentiment(review)`, junto com a franquia.

## Fase 4: gold

São as 6 MVs pedidas: `daily_sales_by_franchise`, `sales_by_product`, `franchise_performance`, `sales_by_country`, `top_customers` e `sentiment_by_franchise`. Todas leem de `${medallion_catalog}.${silver_schema}.*` e gravam em `${medallion_catalog}.${gold_schema}.*`, sem `USE CATALOG` nem `USE SCHEMA`.

## Fase 5: validate e plan (dev e prod), deploy só em dev

- `bundle validate -o json -t dev|prod`: conferir que os schemas resolvem para `bakehouse_dev.bronze` e `bakehouse_prod.bronze`.
- `bundle plan -t dev|prod`: mostrar o que seria criado em cada um.
- **Guarda contra hardcode:** `grep -rnE 'bakehouse_(dev|prod)|\b(bronze|silver|gold)\.' src/ resources/` precisa voltar vazio. Sugestão: levar isso para a CI.
- `bundle deploy -t dev`, depois `bundle run` do job.

## Fase 6: dashboard e conferência de números

Cada query de dataset roda contra `bakehouse_dev.gold.*` e é comparada com a fonte. Por exemplo: receita = 66.471, pedidos = 3.333, ticket = 19,94, franquias ativas = 48, soma por país = soma total, soma por produto = soma total. Só depois disso o dashboard é publicado.

## Fase 7: validação final

- Contagem por camada com nome totalmente qualificado (`bakehouse_dev.<camada>.<tabela>`). Na silver, `transactions` precisa dar 3.333.
- `bakehouse_prod`: `information_schema.schemata` e `tables` precisam estar vazios.

## Críticas e sugestões

1. **A regra "nenhum nome em arquivo nenhum" é impossível ao pé da letra.** O `databricks.yml` precisa ter `catalog: bakehouse_dev` no target, e `schemas.yml` precisa ter `name: bronze`. Leitura proposta: os nomes podem aparecer **só** nas variáveis de target e na declaração dos recursos `schemas:`, e em nenhum lugar de SQL, pipeline, job ou dashboard. O grep da Fase 5 garante isso.
2. **Schemas como recurso do bundle têm um custo.** Um `bundle destroy`, ou remover o recurso do YAML, apaga o schema e todas as tabelas dele. Em dev isso é aceitável. Em prod, vale adicionar proteção na esteira, por exemplo bloquear `destroy` e revisar o `plan` antes de aplicar.
3. **Os reviews e as vendas não se cruzam no tempo.** As vendas vão de 1 a 17/05/2024 e os reviews de 20 a 31/05/2024. O sentimento só pode ser cruzado por franquia, nunca por data. Um filtro de data no dashboard vai zerar os widgets de sentimento ou de vendas, então ele não deve se aplicar aos dois.
4. **`ai_analyze_sentiment` traz três riscos:**
   - Pode não estar disponível na Free Edition. Testar logo no início, com uma única linha.
   - Não é determinístico, então o resultado pode mudar entre um full refresh e outro. A conferência de sentimento precisa ser feita contra a tabela materializada, e não recalculando.
   - Numa MV, um full refresh chama a IA de novo para todos os reviews. Para 204 linhas o custo é trivial, mas em escala uma streaming table é melhor.
5. **Os países pedem uma decisão.** Os clientes estão só em 3 países e as franquias em 9. A padronização só afeta os EUA. Sugestão: gravar também o código ISO-3166 (`US`, `JP`, ...), que é mais robusto. E `sales_by_country` deve usar o **país da franquia**, onde a venda aconteceu, não o do cliente.
6. **Dados sensíveis.** `cardNumber` e os dados pessoais dos clientes (email, telefone, endereço) só deveriam ficar na bronze. Sugestão: descartar `cardNumber` na silver e levar para `top_customers` só nome e ID, sem contato.
7. **Definições de negócio adotadas, salvo objeção:**
   - Cada transação é um pedido, porque há um produto por transação.
   - Ticket médio = receita ÷ pedidos.
   - Franquia ativa = teve pelo menos uma venda no período.
   - Receita sem moeda: a fonte usa um valor único para 9 países, então é tratada como unidade única.
8. **A fonte também está escrita no SQL.** `samples.bakehouse` não é destino, então a regra não se aplica a ela. Mesmo assim, sugestão: parametrizar a fonte também (`${source_catalog}.${source_schema}`), para facilitar trocar a origem no futuro.
9. **Prod e CI/CD.** O target `prod` deveria ter `mode: production`, um `root_path` compartilhado e `run_as` com um service principal. Ainda não existe esteira no repositório, e o `bundle plan -t prod` vai rodar com a identidade do usuário, só para inspeção. Próximo passo possível: um workflow do GitHub Actions.
10. **O repositório é público.** Nenhum token vai para arquivo. O host do workspace no `databricks.yml` não é segredo, mas pode ficar fora e ser resolvido só pelo profile.

11. **O secret do `service_cicd` foi revogado** (2026-11-24) porque estava escrito numa nota. Antes de a esteira rodar de novo, é preciso gerar um secret novo e atualizar o `DATABRICKS_CLIENT_SECRET` no GitHub. Isso não bloqueia o deploy em dev, que usa o profile local.

## Pendências antes de iniciar o desenvolvimento

| # | Pendência | Situação |
|---|---|---|
| 1 | Grant do `service_cicd` em `bakehouse_prod` | **Aberta.** O usuário vai fazer o grant por conta própria, depois que o catálogo existir (passo a passo abaixo) |
| 2 | Decisões dos itens 5 a 7 | **Resolvida.** Adotadas as sugestões: país canônico + código ISO, `sales_by_country` pelo país da franquia; `cardNumber` e contato do cliente só na bronze; pedido = transação, ticket médio = receita ÷ pedidos, franquia ativa = ≥1 venda |
| 3 | Novo secret do `service_cicd` no GitHub | **Resolvida.** `DATABRICKS_CLIENT_ID` e `DATABRICKS_CLIENT_SECRET` cadastrados no repositório `_v2` em 2026-11-24 |

### Como fazer o grant do `service_cicd` (pendência 1)

Só depois de `bakehouse_prod` existir.

1. **Pegar o application ID:** Settings → Identity and access → Service principals → `service_cicd` → campo *Application ID*. Pela CLI:
   ```bash
   databricks service-principals list --profile portfolio-free \
     --filter 'displayName eq "service_cicd"' -o json | jq -r '.[].applicationId'
   ```
2. **Conceder, pela interface:** Catalog → `bakehouse_prod` → aba Permissions → Grant → principal `service_cicd` → marcar só `USE CATALOG` e `CREATE SCHEMA`.
   Ou pelo SQL editor (para service principal, o principal é o application ID):
   ```sql
   GRANT USE CATALOG, CREATE SCHEMA ON CATALOG bakehouse_prod TO `<application-id>`;
   ```
3. **Conferir:**
   ```bash
   databricks grants get catalog bakehouse_prod --profile portfolio-free
   ```
4. **Opcional:** revogar o que foi concedido no catálogo `workspace` na aula, que a v2 não usa:
   ```sql
   REVOKE ALL PRIVILEGES ON CATALOG workspace FROM `<application-id>`;
   ```

## Próximo passo

1. Fase 0.5: criar os catálogos conforme as regras acima e mostrar a conferência.
2. Fase 1 em diante: montar o bundle, validate e plan em dev e prod, deploy só em dev, pipeline, dashboard e validação.

## Resultado da execução em dev (2026-11-24)

| Etapa | Resultado |
|---|---|
| Grep de nomes hardcoded em `src/` e `resources/` | Vazio. Os nomes só aparecem em `databricks.yml` (targets) e `resources/bakehouse.schemas.yml` |
| `bundle validate` dev / prod | OK / OK; os schemas resolvem para `bakehouse_dev.*` e `bakehouse_prod.*` |
| `bundle plan` dev | 6 a criar (3 schemas, pipeline, job, dashboard) |
| `bundle plan` prod | 9 a criar (os mesmos 6 + 3 permissões `CAN_MANAGE`) |
| `bundle deploy -t dev` | 6 recursos criados; a `configuration` da pipeline resolveu para `bronze`, `silver` e `gold` |
| Job `bakehouse_medallion_job` | `TERMINATED SUCCESS` em ~1,5 min; `STREAM(samples...)` funcionou na bronze |
| Expectations | 18 regras, 0 registros reprovados |
| Contagens | bronze = fonte (3.333 / 48 / 300 / 27 / 204); silver sem descartes; gold: 1.816 linhas diárias, 6 produtos, 48 franquias, 9 países, 300 clientes |
| Reconciliação gold × fonte | 18 de 18 checagens com diferença zero |
| Dashboard | Publicado, 8 datasets e 16 widgets, com `bakehouse_dev` / `gold` injetados |
| `bakehouse_prod` | Só `default` e `information_schema`, 0 tabelas |

Observações dos dados:
- **Sentimento:** 85 negativos, 69 mistos, 50 positivos e nenhum neutro.
- **Outliers de ticket médio:** Rome (Itália) tem 105,43 e Stockholm (Suécia) tem 75,20, contra 19,94 na média geral. As duas são as franquias de maior receita, cada uma sozinha no seu país.

Pendências:
1. Grant do `service_cicd` em `bakehouse_prod`, a cargo do usuário.
2. ~~Conferência visual do dashboard~~ **Feita no navegador.** Os 16 widgets renderizam com os números certos (inclusive a ordenação das barras e o tooltip do mapa). Foram corrigidos dois textos cortados (altura 1 → 2) e duas tabelas com rolagem horizontal (saíram "Porte" do ranking e "Cidade" do sentimento).
3. Commit e push para o repositório `_v2`, e depois a esteira CI/CD para prod.
