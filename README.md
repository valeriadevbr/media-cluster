# Media Cluster

Uma stack completa de servidor de mídia baseada em Kubernetes, rodando em ambiente **Dual Cluster** no Kind (Kubernetes in Docker). Este projeto automatiza o deploy de uma suíte de mídia completa, priorizando a resiliência de infraestrutura e o isolamento de aplicações.

## 🏗 Arquitetura Dual-Cluster

O ambiente foi desenhado para separar responsabilidades críticas (DNS/Rede) das aplicações pesadas (Mídia/Transcodificação), garantindo que a infraestrutura básica sobreviva a falhas ou reinícios do cluster de aplicações.

### 1. `infra-cluster` (Infraestrutura)
*   **Responsabilidade**: Serviços essenciais e de baixo nível.
*   **Componentes Principais**:
    *   **BIND9 (DNS)**: Resolve domínios `.media.lan` para toda a rede (Split-Horizon).
    *   **Traefik (Ingress)**: Roteamento de entrada para serviços de infra.
    *   **Cert-Manager**: Gestão de certificados (opcional/futuro).
*   **Objetivo**: Manter a resolução de nomes ativa mesmo se o `media-cluster` estiver indisponível ou sendo recriado.

### 2. `media-cluster` (Aplicações)
*   **Responsabilidade**: Hospedar as aplicações de mídia e gerenciamento.
*   **Componentes Principais**:
    *   **Media Servers**: Plex, Emby (com suporte a transcodificação e acesso direto via HostPort se configurado).
    *   **Arrs**: Sonarr, Radarr, Lidarr, Bazarr, Prowlarr.
    *   **Downloaders**: qBittorrent, Slskd.
    *   **Traefik (Ingress)**: Roteamento dedicado para as aplicações de mídia.
*   **Network Tuning**: O bootstrap deste cluster aplica configurações de sysctl (TCP buffers, MTU, TSO/GRO offload) otimizadas para alto tráfego de mídia.

---

## ☸️ Gerenciando Contextos (Contexts)

Como existem dois clusters rodando simultaneamente, é crucial saber em qual cluster você está executando comandos `kubectl`.

| Cluster | Contexto Kubernetes | Uso |
| :--- | :--- | :--- |
| **Infra** | `kind-infra-cluster` | DNS, Core Networking |
| **Media** | `kind-media-cluster` | Apps de Mídia, Torrents, Logs de Apps |

### Comandos Úteis

Alternar entre contextos:
```bash
# Trabalhar no cluster de Mídia
kubectl config use-context kind-media-cluster

# Trabalhar no cluster de Infra
kubectl config use-context kind-infra-cluster
```

Executar comando em um cluster específico sem mudar o contexto atual:
```bash
kubectl get pods -n infra --context kind-infra-cluster
kubectl get pods -n media --context kind-media-cluster
```

---

## 🚀 Instalação e Setup

### 1. Pré-requisitos
*   **Docker** ou **OrbStack**
*   **Kind** (`brew install kind`)
*   **Kubectl** (`brew install kubectl`)
*   **Configuração**: Copie `.env.template` para `.env` e configure as variáveis de ambiente.

### 2. Inicialização (Bootstrap)

O processo de bootstrap foi unificado. O script principal orquestra a criação dos clusters, tunning de rede e aplicação dos recursos.

```bash
./setup/init.sh
```
*Se preferir rodar manualmente as etapas de K8s:*
```bash
# Cria os clusters e aplica TODOS os recursos (Infra e Media)
./setup/k8s/setup.sh
```

Isso executará sequencialmente os scripts em `setup/k8s/bootstrap/`:
1.  `01-cluster-infra.sh`: Sobe o cluster Infra e aplica tunning de rede.
2.  `02-cluster-media.sh`: Sobe o cluster Media, injeta portas (se configurado) e aplica tunning.
3.  `...`: Instalação de CRDs, Secrets e Cert-Manager.
4.  `09-resources-infra.sh`: Aplica deployments do cluster Infra (Ingress, DNS, etc).
5.  `09-resources-media.sh`: Aplica deployments do cluster Media (Plex, Arrs, etc).

---

## ⚙️ Configurações Avançadas

### Tunning de Rede & Performance
Durante a criação dos clusters, os seguintes ajustes são aplicados aos nós (control-plane) via `sysctl` e `ethtool` para garantir performance máxima em tráfego de rede local e evitar gargalos em transferências SMB/NFS ou streaming 4K:
*   **MTU**: Ajustado para compatibilidade com a rede Docker.
*   **Offloading**: TSO, GSO e GRO são desativados para melhor compatibilidade com alguns drivers de rede virtualizados.
*   **TCP Buffers**: `rmem` e `wmem` ampliados para suportar janelas TCP maiores.

### Mapeamento de Portas (HostPorts)
A variável `MEDIA_SERVERS_IN_CLUSTER` no `.env` controla como Plex e Emby são expostos:
*   **`true`**: As portas (ex: 8920, 32400) são mapeadas diretamente no Host (via `hostPort` e `extraPortMappings` do Kind). Isso permite descoberta automática de DLNA/L2.
*   **`false`**: As aplicações rodam isoladas e o acesso é feito primariamente via Ingress (Traefik).

---

## 📁 Estrutura de Pastas

*   **`setup/k8s/bootstrap/`**: Scripts de ciclo de vida do cluster (Criação -> Configuração -> Deploy de Recursos).
*   **`setup/k8s/infra/`**: Manifestos Kubernetes do cluster Infra.
*   **`setup/k8s/media/`**: Manifestos Kubernetes do cluster Media.
*   **`setup/includes/`**: Bibliotecas de funções Shell compartilhadas (`k8s-utils.sh`, `load-env.sh`).
*   **`scripts/`**: Utilitários para o usuário final.

## 🧹 Unload / Destruição

Para remover ambos os clusters e limpar o ambiente:

```bash
./setup/k8s/unload.sh
```
