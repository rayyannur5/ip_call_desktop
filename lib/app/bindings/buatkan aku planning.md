buatkan aku planning
Aku mau migrasi dari project ku di /Users/user/Projects/ip_call_app yang mana ini adalah js dari vite, mau tak pindah ke flutter

requirement struktur
pisah setiap service
mqtt_client: ^10.11.11
sip_ua: ^1.1.0

framework
get: ^5.0.0-release-candidate-9.3.3


seluruh logika mqtt harus sama persis dengan project sebelumnya kecuali sip handling, yang mana di project sebelumnya pakai mqtt, yang ini handle pakai sip_ua

buatkan fitur tambahan yaitu
- ganti host server (jangan hardcoded, pakai get storage)

untuk device linux, tambah fitur
- connect ke wifi pakai sudo nmcli, lewat exec
- ubah volume pakai amixer set Capture/Master
- read volume sekarang


pisah antara service, controller, dan view

ini akan di build untuk desktop, yaitu windows, linux, dan mac

currently ini aku develop pakai mac