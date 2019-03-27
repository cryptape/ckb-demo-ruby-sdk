require_relative "lib/ckb/wallet"

api = Ckb::Api.new
tip_number = api.get_tip_number

api.load_default_configuration!

bob = Ckb::Wallet.from_hex(api, "e79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")
token_info = bob.created_token_info("Token 1")
bob_token1 = bob.udt_wallet(token_info)

while bob_token1.deposit_cells.empty?
    sleep 1
end

deposit_cell = bob_token1.deposit_cells[0]

p deposit_cell[:amount]
