# 🚀 Quick Start - Mineclifford 2.0

## 5 Minutos para seu Primeiro Deploy

### Passo 1: Instalação (2 min)

```bash
cd Mineclifford-Server
./install.sh
```

### Passo 2: Configurar Cloud (1 min)

```bash
# AWS
aws configure

# OU Azure
az login
```

### Passo 3: Gerar Configuração (1 min)

```bash
# Gerar vars para Paper mais recente
python3 src/ansible_integration.py generate \
  --java-type paper \
  --java-version latest \
  --java-memory 4G \
  -o deployment/ansible/minecraft_vars.yml
```

### Passo 4: Deploy! (1 min de comando, ~5 min de execução)

```bash
./minecraft-ops.sh deploy --provider aws --orchestration swarm
```

### Passo 5: Conectar

```bash
# Obter IP do servidor
terraform output -state=terraform/aws/terraform.tfstate server_ip

# Conectar no Minecraft
# IP: <output-acima>
# Porta: 25565
```

## 🎮 Comandos Úteis

```bash
# Ver status
./minecraft-ops.sh status --provider aws

# Listar versões disponíveis
mineclifford-version list paper

# Comparar server types
mineclifford-version compare 1.20.1

# Destruir infraestrutura
./minecraft-ops.sh destroy --provider aws
```

## 📚 Próximos Passos

- Ler documentação completa: `docs/version-manager.md`
- Ver exemplos: `examples/`
- Explorar Version Manager: `mineclifford-version --help`

**Pronto! Seu servidor Minecraft está rodando!** 🎉
