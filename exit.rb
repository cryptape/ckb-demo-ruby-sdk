require_relative "lib/ckb/wallet"

api = Ckb::Api.new
tip_number = api.get_tip_number

api.load_default_configuration!

bob = Ckb::Wallet.from_hex(api, "e79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")
token_info = bob.created_token_info("Token 1")
bob_token1 = bob.udt_wallet(token_info)

deposit = bob_token1.get_deposit_balance

p "bob_token1.get_deposit_balance: #{deposit}"
p "bob_token1.get_balance: #{bob_token1.get_balance}"
puts "\n\n"

raise "Bob deposit balance should be 4000, but got #{deposit}" if deposit != 4000

deposit_cell = bob_token1.deposit_cells[0]

p "Deposit balance cell: #{deposit_cell}"
puts "\n\n"

p "Bob exit the whole deposit balance"
p "waiting..."
bob_token1.exit(deposit_cell)

while bob_token1.get_deposit_balance != 0
    sleep 1
end

p "Success!"
p "Now the deposit balance is 0, the balance is #{bob_token1.get_balance}"
