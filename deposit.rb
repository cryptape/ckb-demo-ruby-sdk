require_relative "lib/ckb/wallet"

api = Ckb::Api.new
tip_number = api.get_tip_number

api.load_default_configuration!

bob = Ckb::Wallet.from_hex(api, "e79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")
token_info = bob.created_token_info("Token 1")
bob_token1 = bob.udt_wallet(token_info)

p "Bob deposits 4000 tokens"

bob_token1.deposit(4000, 5000)

while bob_token1.get_deposit_balance != 4000
    sleep 1
end

p "bob_token1 deposit_balance: #{bob_token1.get_deposit_balance}"
p "bob_token1 balance: #{bob_token1.get_balance}"
p "bob balance: #{bob.get_balance}"

p "Success!"
puts "\n\n"
