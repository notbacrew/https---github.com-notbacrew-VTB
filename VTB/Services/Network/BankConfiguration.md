# Конфигурация подключения к банкам

## VBank
- API документация: https://vbank.open.bankingapi.ru/docs
- Base URL: https://vbank.open.bankingapi.ru/api/v1
- OAuth Endpoints:
  - Authorization: https://vbank.open.bankingapi.ru/oauth/authorize
  - Token: https://vbank.open.bankingapi.ru/oauth/token
- **Важно:**
  - `team225-1` - это логин для входа в VBank (может использоваться для других операций)
  - `team225` (без суффикса) - это client_id для endpoint `/auth/bank-token` (получение токена)
  - Для получения токена через `/auth/bank-token` всегда используется `team225` без суффикса
- Для получения Client ID необходимо зарегистрировать приложение в портале разработчика VBank

## SBank
- API документация: https://sbank.open.bankingapi.ru/docs
- Base URL: https://sbank.open.bankingapi.ru/api/v1
- OAuth Endpoints:
  - Authorization: https://sbank.open.bankingapi.ru/oauth/authorize
  - Token: https://sbank.open.bankingapi.ru/oauth/token
- Для получения Client ID необходимо зарегистрировать приложение в портале разработчика SBank

## ABank
- API документация: https://abank.open.bankingapi.ru/docs
- Base URL: https://abank.open.bankingapi.ru/api/v1
- OAuth Endpoints:
  - Authorization: https://abank.open.bankingapi.ru/oauth/authorize
  - Token: https://abank.open.bankingapi.ru/oauth/token
- Для получения Client ID необходимо зарегистрировать приложение в портале разработчика ABank

## ГОСТ-шлюз (GOST Gateway)

### Общая информация
ГОСТ-шлюз предоставляет доступ к банковским API через стандарты Банка России с использованием ГОСТ протоколов шифрования.

### Аутентификация
Для получения токена доступа используется отдельный endpoint:
- **URL**: `https://auth.bankingapi.ru/auth/realms/kubernetes/protocol/openid-connect/token`
- **Метод**: POST
- **Content-Type**: `application/x-www-form-urlencoded`
- **Параметры в body**:
  - `grant_type=client_credentials`
  - `client_id=<client_id>`
  - `client_secret=<client_secret>`

Пример curl запроса:
```bash
curl -v --data 'grant_type=client_credentials&client_id=<client_id>&client_secret=<client_secret>' \
  https://auth.bankingapi.ru/auth/realms/kubernetes/protocol/openid-connect/token
```

### API Endpoints
- **Base URL**: `https://api.gost.bankingapi.ru:8443`
- **Формат пути**: `/api/rb/rewardsPay/hackathon/v1/...`

Пример полного URL:
```
https://api.gost.bankingapi.ru:8443/api/rb/rewardsPay/hackathon/v1/accounts/external/{externalAccountID}/rewards/balance
```

### Требования для работы с ГОСТ-шлюзом
1. Наличие openssl, совместимого с GOST-протоколами шифрования
2. Наличие curl, совместимого с GOST-протоколами шифрования
3. Наличие доверенного сертификата КриптоПРО (доступен для получения на тестовый период в 1 месяц на официальном сайте) для формирования TLS over HTTPS связи

### Реестр API
Для изучения спецификаций API:
1. Зайти в Реестр: https://api-registry-frontend.bankingapi.ru/
2. Изучить спецификации API
3. Нажать на Карточку API, которую нужно просмотреть
4. Нажать на кнопку «Открыть редактор»
5. Перейти на вкладку «Обзор» или «Код-Редактор»

## Настройка Client ID

После регистрации приложения в каждом банке, необходимо сохранить Client ID в UserDefaults:
- `vbank_client_id` - для VBank
- `sbank_client_id` - для SBank
- `abank_client_id` - для ABank
- `gost_client_id` - для ГОСТ-шлюза

Или добавить в SettingsView возможность настройки Client ID для каждого банка.

