# NmiDirectPost

NmiDirectPost is a gem that encapsulates the NMI Direct Post API in an ActiveRecord-like syntax.
For more information on the NMI Direct Post API, see:
    https://secure.nmi.com/merchants/resources/integration/integration_portal.php

To mimic ActivRecord syntax, it is necessary to blur, from the client's standpoint, the boundary between NMI's Direct Post API and its Query API.  This fuzziness is part of the encapsulation.

## Installation

Add this line to your application's Gemfile:

    gem 'nmi_direct_post'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nmi_direct_post

## Usage

1) Before you can query or post, establish the connection:

    NmiDirectPost::Base.establish_connection("MY_NMI_USERNAME", "MY_NMI_PASSWORD")

Theoretically, you can use a different connection for NmiDirectPost::Transaction or NmiDirectPost::CustomerVault by calling establish_connection on either of those derived classes, instead of on Base.
However, it's hard to imagine a case where this would be useful; the option is only present to mimic the syntax of ActiveRecord.

2) Query the API:

    NmiDirectPost::Transaction.find_by_transaction_id(123456789)
    NmiDirectPost::CustomerVault.find_by_customer_vault_id(123123123)

3) Create a CustomerVault:

    george = NmiDirectPostCustomerVault.new(:first_name => 'George', :last_name => 'Washington', :cc_number => '4111111111111111', :cc_exp => '03/17')
    george.create

4) Update a CustomerVault:

    george.update!(:email => 'el_primero_presidente@whitehouse.gov', :address_1 => '1600 Pennsylvania Ave NW', :city => 'Washington', :state => 'DC', :postal_code => '20500')

  ALTERNATIVELY:

    george.email = 'el_primero_presidente@whitehouse.gov'
    george.address_1 = '1600 Pennsylvania Ave NW'
    george.city = 'Washington'
    george.state = 'DC'
    george.postal_code = '20500'
    george.save! # Returns true

5) Delete a CustomerVault:

    george.destroy # Returns the CustomerVault

6) Reload a CustomerVault:

    george.email = 'el_primero_presidente@whitehouse.gov'
    george.reload # Returns the Customer Vault
    george.email # Returns the previously set email

7) CustomerVault class methods:

    NmiDirectPost::CustomerVault.all_ids # Returns array of `customer_vault_id`s
    NmiDirectPost::CustomerVault.first
    NmiDirectPost::CustomerVault.last
    NmiDirectPost::CustomerVault.all # Returns very, very big array.  This method had very poor performance and could be optimized significantly in a future version of this gem.

8) Create a Transaction:

    parking_ticket = NmiDirectPost::Transaction(:type => :sale, :amount => 150.01, :customer_vault_id => george.customer_vault_id)
    parking_ticket.save! # Returns true

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
