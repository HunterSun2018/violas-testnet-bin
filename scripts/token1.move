address 0x7257c2417e4d1038e1817c8f283ace2e:

module ViolasToken {
    use 0x0::LibraAccount;
    use 0x0::Transaction;
    use 0x0::U64Util;
    use 0x0::AddressUtil;
    use 0x0::Vector;
    use 0x0::LibraTimestamp;
    // use 0x0::LibraTransactionTimeout;
    // use 0x0::LibraCoin;
    // use 0x0::Hash;

    resource struct Supervisor {
    }

    resource struct T {
	index: u64,
	value: u64,
    }

    resource struct BorrowInfo {
	principal: u64,
	interest_index: u64,
    }

    resource struct Tokens {
	ts: vector<T>,
	borrows: vector<BorrowInfo>,
    }

    resource struct Order {
	t: T,
	peer_token_idx: u64,
	peer_token_amount: u64,
    }
    
    resource struct UserInfo {
	violas_events: LibraAccount::EventHandle<ViolasEvent>,
	data: vector<u8>,
	orders: vector<Order>,
	order_freeslots: vector<u64>,
    }

    resource struct TokenInfo {
	owner: address,
	total_supply: u64,
	total_reserves: u64,
	total_borrows: u64,
	borrow_index: u64,
	price: u64,
	price_oracle: address,
	collateral_factor: u64,
	last_minute: u64,
	data: vector<u8>,
	bulletin_first: vector<u8>,
	bulletins: vector<vector<u8>>,
    }

    resource struct TokenInfoStore {
	tokens: vector<TokenInfo>,
    }

    struct ViolasEvent {
	etype: u64,
	paras: vector<u8>,
	data:  vector<u8>,
    }

    fun contract_address() : address {
	0x7257c2417e4d1038e1817c8f283ace2e
    }
    
    fun require_published() {
	Transaction::assert(exists<Tokens>(Transaction::sender()), 101);
    }

    fun require_supervisor() {
	Transaction::assert(exists<Supervisor>(Transaction::sender()), 102);
    }
    
    fun require_owner(tokenidx: u64) acquires TokenInfoStore {
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let len = Vector::length(&tokeninfos.tokens);
	Transaction::assert(tokenidx < len , 103);
	let token = Vector::borrow(&tokeninfos.tokens, tokenidx);
	Transaction::assert(token.owner == Transaction::sender(), 104);
    }

    fun extend_user_tokens(payee: address) acquires TokenInfoStore, Tokens {
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let tokencnt = Vector::length(&tokeninfos.tokens);
	let tokens = borrow_global_mut<Tokens>(payee);
	let usercnt = Vector::length(&tokens.ts);
	loop {
	    if(usercnt >= tokencnt) break;
	    Vector::push_back(&mut tokens.ts, T{ index: usercnt, value: 0});
	    Vector::push_back(&mut tokens.borrows, BorrowInfo{ principal: 0, interest_index: 0});
	    usercnt = usercnt + 1;
	}
    }

    public fun join(t1: T, t2: T) : T {
	let T { index: i1, value: v1 } = t1;
	let T { index: i2, value: v2 } = t2;
	Transaction::assert(i1 == i2, 202);
	T { index: i1, value: v1+v2 }
    }

    public fun join2(t1: &mut T, t2: T) {
	let T { index: i2, value: v2 } = t2;
	Transaction::assert(t1.index == i2, 202);
	t1.value = t1.value + v2;
    }
    
    public fun split(t: &mut T, amount: u64) : T {
	Transaction::assert(t.value >= amount, 203);
	t.value = t.value - amount;
	T { index: t.index, value: amount }
    }
    
    public fun deposit(payee: address, to_deposit: T) acquires TokenInfoStore,Tokens {
	extend_user_tokens(payee);
	let T { index, value } = to_deposit;
	let tokens = borrow_global_mut<Tokens>(payee);
	let t = Vector::borrow_mut(&mut tokens.ts, index);
	t.value = t.value + value; 
    }

    fun withdraw_from(tokenidx: u64, payer: address, amount: u64) : T acquires Tokens {
	let tokens = borrow_global_mut<Tokens>(payer);
	let t = Vector::borrow_mut(&mut tokens.ts, tokenidx);
	Transaction::assert(t.value >= amount, 105);
	t.value = t.value - amount;
	T { index: tokenidx, value: amount }
    }
    
    public fun withdraw(tokenidx: u64, amount: u64) : T acquires Tokens {
	let tokens = borrow_global_mut<Tokens>(Transaction::sender());
	let t = Vector::borrow_mut(&mut tokens.ts, tokenidx);
	Transaction::assert(t.value >= amount, 105);
	t.value = t.value - amount;
	T { index: tokenidx, value: amount }
    }
    
    fun pay_from_sender(tokenidx: u64, payee: address, amount: u64) acquires TokenInfoStore,Tokens {
    	let t = withdraw(tokenidx, amount);
    	deposit(payee, t);
    }
    
    fun emit_events(etype: u64, paras: vector<u8>, data: vector<u8>) acquires UserInfo {
	let info = borrow_global_mut<UserInfo>(Transaction::sender());
	LibraAccount::emit_event<ViolasEvent>(&mut info.violas_events, ViolasEvent{ etype: etype, paras: paras, data: data});
    }

    public fun zero(tokenidx: u64) : T {
	T { index: tokenidx, value: 0 }
    }

    public fun value(coin_ref: &T): u64 {
    	coin_ref.value
    }

    public fun balance_of(tokenidx: u64, account: address) : u64 acquires Tokens {
	let tokens = borrow_global<Tokens>(account);
	if(tokenidx < Vector::length(&tokens.ts)) {
	    let t = Vector::borrow(& tokens.ts, tokenidx);
	    t.value
	} else { 0 }
    }
    
    public fun balance(tokenidx: u64) : u64 {
	balance_of(tokenidx, Transaction::sender())
    }
    
    public fun token_count() : u64 acquires TokenInfoStore {
	let tokeninfos = borrow_global<TokenInfoStore>(contract_address());
	Vector::length(&tokeninfos.tokens)
    }

    public fun total_supply(tokenidx: u64) : u64 acquires TokenInfoStore {
	let tokeninfos = borrow_global<TokenInfoStore>(contract_address());
	let token = Vector::borrow(& tokeninfos.tokens, tokenidx);
	token.total_supply
    }
    
    public fun publish(userdata: vector<u8>) acquires UserInfo {
	let sender = Transaction::sender();
	Transaction::assert(!exists<Tokens>(sender), 106);
	move_to_sender<Tokens>(Tokens{ ts: Vector::empty(), borrows: Vector::empty() });

	move_to_sender<UserInfo>(UserInfo{
	    violas_events: LibraAccount::new_event_handle<ViolasEvent>(),
	    data: *&userdata,
	    orders: Vector::empty(),
	    order_freeslots: Vector::empty(),
	});

	if(sender == contract_address()) {
	    move_to_sender<Supervisor>(Supervisor{});
	    move_to_sender<TokenInfoStore>(TokenInfoStore{ tokens: Vector::empty() });
	};
	
	emit_events(0, userdata, Vector::empty());
    }

    public fun create_token(owner: address, priceoracle: address, collateralfactor: u64, tokendata: vector<u8>) : u64 acquires TokenInfoStore, UserInfo {
	require_published();
	require_supervisor();
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let len = Vector::length(&tokeninfos.tokens);
	let mantissa_one = new_mantissa(1, 1);
	Vector::push_back(&mut tokeninfos.tokens, TokenInfo {
	    owner: owner,
	    total_supply: 0,
	    total_reserves: 0,
	    total_borrows: 0,
	    borrow_index: mantissa_one,
	    price: 0,
	    price_oracle: priceoracle,
	    collateral_factor: collateralfactor,
	    last_minute: LibraTimestamp::now_microseconds() / (60*1000*1000),
	    data: *&tokendata,
	    bulletin_first: Vector::empty(),
	    bulletins: Vector::empty()
	});
	Vector::push_back(&mut tokeninfos.tokens, TokenInfo {
	    owner: 0x0,
	    total_supply: 0,
	    total_reserves: 0,
	    total_borrows: 0,
	    borrow_index: mantissa_one,
	    price: 0,
	    price_oracle: priceoracle,
	    collateral_factor: collateralfactor,
	    last_minute: LibraTimestamp::now_microseconds() / (60*1000*1000),
	    data: *&tokendata,
	    bulletin_first: Vector::empty(),
	    bulletins: Vector::empty()
	});	
	
	let v = AddressUtil::address_to_bytes(owner);
	Vector::append(&mut v, tokendata);
	emit_events(1, v, U64Util::u64_to_bytes(len));
	len
    }

    public fun mint(tokenidx: u64, payee: address, amount: u64, data: vector<u8>) acquires TokenInfoStore, Tokens, UserInfo {
	require_published();
	require_owner(tokenidx);
	let t = T{ index: tokenidx, value: amount };
	deposit(payee, t);

	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
	token.total_supply = token.total_supply + amount;

	let v = U64Util::u64_to_bytes(tokenidx);
	Vector::append(&mut v, AddressUtil::address_to_bytes(payee));
	Vector::append(&mut v, U64Util::u64_to_bytes(amount));
	Vector::append(&mut v, data);
	emit_events(2, v, Vector::empty());
    }
    
    public fun transfer(tokenidx: u64, payee: address, amount: u64, data: vector<u8>) acquires TokenInfoStore, Tokens,  UserInfo {
	require_published();
	pay_from_sender(tokenidx, payee, amount);
	
	let v = U64Util::u64_to_bytes(tokenidx);
	Vector::append(&mut v, AddressUtil::address_to_bytes(payee));
	Vector::append(&mut v, U64Util::u64_to_bytes(amount));
	Vector::append(&mut v, data);
	emit_events(3, v, Vector::empty());
    }

    fun transfer_from(tokenidx: u64, payer: address, payee: address, amount: u64) acquires TokenInfoStore, Tokens,  UserInfo {
	require_published();
	let t = withdraw_from(tokenidx, payer, amount);
	deposit(payee, t)
    }
    
    fun bank_mint(tokenidx: u64, payee: address, amount: u64) acquires TokenInfoStore, Tokens {
	let t = T{ index: tokenidx, value: amount };
	deposit(payee, t);
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
	token.total_supply = token.total_supply + amount;
    }
    
    fun accrue_interest(tokenidx: u64) {
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);

	let minute = LibraTimestamp::now_microseconds() / (60*1000*1000);
	let cnt = minute - token.last_minute;
	token.last_minute = minute;
	
	let borrowrate = borrow_rate(tokenidx)*cnt;
	let interest_accumulated = mantissa_mul(token.totol_borrows, borrowrate);
	token.totol_borrows = token.total_borrows + interest_accumulated;

	let reserve_factor = new_mantissa(1, 1000);
	token.total_reserves = token.total_reserves + mantissa_mul(interest_accumulated, reserve_factor);

	token.borrow_index = token.borrow_index + mantissa_mul(token.borrow_index, borrowrate);
    }

    fun new_mantissa(a: u64, b: u64) : u64 {
	let c = (a as u128) << 64;
	let d = (b as u128) << 32;
	let e = c / d;
	Transaction::assert(e != 0 || a == 0, 16);
	(e as u64)
    }
    
    fun mantissa_div(a: u64, b: u64) : u64 {
	let c = (a as u128) << 32;
	let d = c / (b as u128);
	(d as u64)
    }

    fun mantissa_mul(a: u64, b: u64) : u64 {
	let c = (a as u128) * (b as u128);
	let d = c >> 32;
	(d as u64)
    }
    
    fun exchange_rate(tokenidx: u64) : u64 {
	let tokens = borrow_global<Tokens>(contract_address());
	let t = Vector::borrow(& tokens.ts, tokenidx);
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
	let token1 = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx+1);
	
	if(token1.total_supply == 0) {
	    new_mantissa(1, 100)
	} else {
	    // exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
	    new_mantissa(t.value+token.total_borrows-token.total_reserves, token1.total_supply)
	}
    }

    fun borrow_rate(tokenidx: u64) : u64 {
	let tokens = borrow_global<Tokens>(contract_address());
	let t = Vector::borrow(& tokens.ts, tokenidx);
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
	
	// utilization rate of the market: `borrows / (cash + borrows - reserves)`
	let util = 0;
	if(t.value <= token.total_reserves) {
	    util = new_mantissa(1,1);
	} else {
	    util = new_mantissa(token.total_borrows, t.value + token.total_borrows - token.total_reserves);
	};
	let baserate_perminute = new_mantissa(5, 100*60*24*365);
	baserate_perminute + mantissa_mul(baserate_perminute, util)
    }

    fun borrow_balance_of(tokenidx: u64, account: address) : u64 {
	// recentBorrowBalance = borrower.borrowBalance * market.borrowIndex / borrower.borrowIndex
	let tokens = borrow_global<Tokens>(account);
	let borrowinfo = Vector::borrow(& tokens.borrows, tokenidx);
	
	let tokeninfos = borrow_global<TokenInfoStore>(contract_address());
	let token = Vector::borrow(& tokeninfos.tokens, tokenidx);
	
	borrowinfo.principal * token.borrow_index / borrowinfo.interest_index
    }

    fun borrow_balance(tokenidx: u64) {
	borrow_balance_of(tokenidx, Transaction::sender())
    }

    public fun update_price(tokenidx: u64, price: u64) {
	Transaction::assert(tokenidx % 2 == 0, 302);
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
	Transaction::assert(token.price_oracle == Transaction::sender(), 303);
	token.price = price;
    }
    
    public fun lock(tokenidx: u64, amount: u64, data: vector<u8>) {
	let sender = Transaction::sender();
	accrue_interest();
	let er = exchange_rate(tokendix);
	pay_from_sender(tokenidx, contract_address(), amount);
	let tokens = mantissa_div(amount, er);
	bank_mint(tokenidx+1, sender, tokens);
    }

    fun bank_token_2_base(amount: u64, exange_rate: u64, collateral_factor: u64, price: u64) : u64 {
	let value = mantissa_mul(amount, exchange_rate);
	value = mantissa_mul(value, collateral_factor);
	value = mantissa_mul(value, price);
	value
    }
    
    fun account_liquidity(account: address, modify_tokenidx: u64, redeem_tokens: u64, borrow_amount: u64) : (u64, u64) {
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let len = Vector::length(& tokeninfos.tokens);
	let tokens = borrow_global<Tokens>(account);
	
	let i = 0;
	let sum_collateral = 0;
	let sum_borrow = 0;
	
	loop {
	    if(i == len) break;
	    let token = Vector::borrow_mut(&mut tokeninfos.tokens, i);
	    let token1 = Vector::borrow_mut(&mut tokeninfos.tokens, i+1);
	    
	    let value = 0;
	    let value = bank_token_2_base(balance_of(i+1, account), exchange_rate(i), token.collateral_factor, token.price);
	    sum_collateral = sum_collateral + value;

	    sum_borrow = sum_borrow + mantissa_mul(borrow_balance_of(i, account), token.price);

	    if(i == modify_tokenidx) {
		if(redeem_tokens > 0) {
		    sum_borrow = sum_borrow + bank_token_2_base(redeem_tokens, exchange_rate(i), token.collateral_factor, token.price);
		};
		if(borrow_amount > 0) {
		    sum_borrow = sum_borrow + mantissa_mul(borrow_amount, token.price);
		};
	    };
	    
	    i = i + 2;
	};
	
	(sum_collateral, sum_borrow)
    }
    
    public fun redeem(tokenidx: u64, amount: u64, data: vector<u8>) {
	let sender = Transaction::sender();
	accrue_interest();
	let er = exchange_rate();

	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
	let token1 = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx+1);

	let tokencnt_amount = mantissa_div(amount, er);
	if(amount == 0) {
	    token_amount = balance(tokenidx+1);
	    amount = mantissa_mul(token_amount, er);
	};

	let (sum_collateral, sum_borrow) = account_liquidity(sender, tokenidx, token_amount, 0);
	Transaction::assert(sum_collateral >= sum_borrow, 307);
	
	let T{_, _} = withdraw(tokenidx+1, token_amount);
	token1.total_supply = token1.total_supply - token_amount;
	
	transfer_from(tokenidx, contract_address(), sender, amount);
    }

    public fun borrow(tokenidex: u64, amount: u64, data: vector<u8>) {
	let sender = Transaction::sender();
	accrue_interest();
	// let er = exchange_rate();
	
	let value = mantissa_mul(amount, token.price);
	let (sum_collateral, sum_borrow) = account_liquidity(sender, tokenidx, 0, amount);
	Transaction::assert(sum_collateral >= sum_borrow, 304);

	let balance = borrow_balance(tokenidx);

	let tokens = borrow_global_mut<Tokens>(Transaction::sender());
	let borrowinfo = Vector::borrow_mut(&mut tokens.borrows, tokenidx);

	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let ti = Vector::borrow(&mut tokeninfos.tokens, tokenidx);

	ti.total_borrows = ti.total_borrows + amount;
	borrowinfo.principal = borrowinfo.principal + amount;
	borrowinfo.interest_index = ti.borrow_index;
	
	transfer_from(tokenidx, contract_address(), sender, amount);
    }
    
    fun repay_borrow_for(tokenidx: u64, borrower: address, amount: u64) {
	let sender = Transaction::sender();

	let balance = borrow_balance_of(tokenidx, borrower);
	Transaction::assert(amount <= balance, 305);
	if(amount == 0) { amount = balance; };

	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let ti = Vector::borrow(&mut tokeninfos.tokens, tokenidx);
	ti.total_borrows = ti.total_borrows - amount;

	let tokens = borrow_global_mut<Tokens>(borrower);
	let borrowinfo = Vector::borrow_mut(&mut tokens.borrows, tokenidx);
	borrowinfo.principal = balance - amount;
	borrowinfo.interest_index = ti.borrow_index;
	    
	pay_from_sender(tokenidx, contract_address(), amount);
    }

    public repay_borrow(tokenidx: u64, amount: u64) {
	accrue_interest();
	repay_borrow_for(tokenidx, Transaction::sender(), amount)
    }
    
    public fun liquidate_borrow(tokenidx: u64, borrower: address, amount: u64, collateral_tokenidx: u64) {
	let sender = Transaction::sender();
	accrue_interest();

	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let ti = Vector::borrow(&mut tokeninfos.tokens, tokenidx);
	let ti1 = Vector::borrow(&mut tokeninfos.tokens, collateral_tokenidx);

	let (sum_collateral, sum_borrow) = account_liquidity(borrower);
	Transaction::assert(sum_collateral < sum_borrow, 306);

	let borrowed = borrow_balance_of(tokenidx, borrower);
	Transaction::assert(amount <= borrowed, 306);

	if(amount == 0) { amount = borrowed; };
	
	let base_amount = mantissa_mul(amount, ti.price);
	Transaction::assert(base_amount <= (sum_borrow - sum_collateral), 306);
	
	repay_borrow_for(tokenidx, borrower, amount);

	// amount1 * price1 = amount2 * exchange_rate2 * price2
	let value = mantissa_mul(amount, ti.price);
	value = mantissa_div(value, exchange_rate(collateral_tokenidx));
	value = mantissa_div(value, ti1.price);
	value = value + mantissa_mul(value, new_mantissa(1, 10));

	transfer_from(collateral_tokenidx, borrower, sender, value);
    }
    
    // public fun make_order(idxa: u64, amounta: u64, idxb: u64, amountb: u64, data: vector<u8>) : u64 acquires Tokens, UserInfo {
    // 	require_published();
    // 	Transaction::assert(amounta > 0, 201);

    // 	let t = withdraw(idxa, amounta);
    // 	let info = borrow_global_mut<UserInfo>(Transaction::sender());
    // 	let len = Vector::length(&info.orders);
    // 	let idx = len;

    // 	Vector::push_back(&mut info.orders, Order { t: t, peer_token_idx: idxb, peer_token_amount: amountb});	    
	
    // 	if(!Vector::is_empty(&info.order_freeslots)) {
    // 	    idx = Vector::pop_back(&mut info.order_freeslots);
    // 	    let order = Vector::swap_remove(&mut info.orders, idx);
    // 	    let Order { t: T { index:_, value:_ }, peer_token_idx:_, peer_token_amount:_ } = order;
    // 	};
	
    // 	let v = U64Util::u64_to_bytes(idxa);
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(amounta));
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(idxb));
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(amountb));
    // 	Vector::append(&mut v, data);
    // 	emit_events(4, v, U64Util::u64_to_bytes(idx));

    // 	idx
    // }

    // public fun cancel_order(orderidx: u64, idxa: u64, amounta: u64, idxb: u64, amountb: u64, data: vector<u8>) acquires TokenInfoStore,Tokens, UserInfo {
    // 	require_published();
    // 	let info = borrow_global_mut<UserInfo>(Transaction::sender());
	
    // 	Vector::push_back(&mut info.orders, Order { t: T{ index: 0, value: 0}, peer_token_idx: 0, peer_token_amount: 0});	    
    // 	Vector::push_back(&mut info.order_freeslots, orderidx);
    // 	let order = Vector::swap_remove(&mut info.orders, orderidx);
	
    // 	Transaction::assert(order.t.index == idxa, 107);
    // 	Transaction::assert(order.t.value == amounta, 108);
    // 	Transaction::assert(order.peer_token_idx == idxb, 109);
    // 	Transaction::assert(order.peer_token_amount == amountb, 110);
	
    // 	let Order { t: t, peer_token_idx:_, peer_token_amount:_ } = order;
    // 	deposit(Transaction::sender(), t);
	
    // 	let v = U64Util::u64_to_bytes(idxa);
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(amounta));
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(idxb));
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(amountb));
    // 	Vector::append(&mut v, data);
    // 	emit_events(5, v, Vector::empty());
    // }
    
    // public fun take_order(maker: address, orderidx: u64, idxa: u64, amounta: u64, idxb: u64, amountb: u64, data: vector<u8>) acquires TokenInfoStore, Tokens, UserInfo {
    // 	require_published();
    // 	let info = borrow_global_mut<UserInfo>(maker);
    // 	let len = Vector::length(&info.orders);
    // 	Vector::push_back(&mut info.orders, Order { t: T {index: idxa, value: 0}, peer_token_idx: idxb, peer_token_amount: amountb });

    // 	let order = Vector::swap_remove(&mut info.orders, orderidx);
	
    // 	Transaction::assert(order.t.index == idxa, 111);
    // 	Transaction::assert(order.t.value == amounta, 112);
    // 	Transaction::assert(order.peer_token_idx == idxb, 113);
    // 	Transaction::assert(order.peer_token_amount == amountb, 114);

    // 	pay_from_sender(idxb, maker, amountb);
    // 	let Order { t: t, peer_token_idx:_, peer_token_amount:_ } = order;
    // 	deposit(Transaction::sender(), t );

	
    // 	if(len == orderidx+1) {
    // 	    let o = Vector::pop_back(&mut info.orders);
    // 	    let Order { t: T { index:_, value:_ }, peer_token_idx:_, peer_token_amount:_ } = o;
    // 	} else {
    // 	    Vector::push_back(&mut info.order_freeslots, orderidx);
    // 	};

    // 	let v = AddressUtil::address_to_bytes(maker);
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(orderidx));
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(idxa));
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(amounta));
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(idxb));
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(amountb));
    // 	Vector::append(&mut v, data);
    // 	emit_events(6, v, Vector::empty());
    // }
    
    public fun move_owner(tokenidx: u64, new_owner: address, data: vector<u8>) acquires TokenInfoStore, UserInfo {
	require_published();
	require_owner(tokenidx);
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
	token.owner = new_owner;

	let v = U64Util::u64_to_bytes(tokenidx);
	Vector::append(&mut v, AddressUtil::address_to_bytes(new_owner));
	Vector::append(&mut v, data);
	emit_events(7, v, Vector::empty());
    }

    // public fun update_first_bulletin(tokenidx: u64, data: vector<u8>) acquires TokenInfoStore, UserInfo {
    // 	require_published();
    // 	require_owner(tokenidx);
    // 	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
    // 	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
    // 	token.bulletin_first = *&data;
	
    // 	let v = U64Util::u64_to_bytes(tokenidx);
    // 	Vector::append(&mut v, data);
    // 	emit_events(8, v, Vector::empty());
    // }

    // public fun append_bulletin(tokenidx: u64, data: vector<u8>) acquires TokenInfoStore, UserInfo {
    // 	require_published();
    // 	require_owner(tokenidx);
    // 	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
    // 	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
    // 	Vector::push_back(&mut token.bulletins, *&data);

    // 	let v = U64Util::u64_to_bytes(tokenidx);
    // 	Vector::append(&mut v, data);
    // 	emit_events(9, v, Vector::empty());
    // }

    // public fun destroy_owner(tokenidx: u64, data: vector<u8>) acquires TokenInfoStore, UserInfo{
    // 	require_published();
    // 	require_owner(tokenidx);
    // 	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
    // 	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
    // 	token.owner = 0x0;

    // 	let v = U64Util::u64_to_bytes(tokenidx);
    // 	Vector::append(&mut v, data);
    // 	emit_events(10, v, Vector::empty());
    // }
    
    // public fun destroy_coin(tokenidx: u64, amount: u64, data: vector<u8>) acquires TokenInfoStore, Tokens, UserInfo{
    // 	require_published();
    // 	require_owner(tokenidx);
    // 	T { index: _, value: _ } = withdraw(tokenidx, amount);
	
    // 	let v = U64Util::u64_to_bytes(tokenidx);
    // 	Vector::append(&mut v, U64Util::u64_to_bytes(amount));
    // 	Vector::append(&mut v, data);
    // 	emit_events(11, v, Vector::empty());
    // }

    // public fun record(data: vector<u8>) acquires UserInfo {
    // 	require_published();
    // 	emit_events(12, data, Vector::empty());
    // }
}

