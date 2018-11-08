require('babel-register');
require('babel-polyfill');

module.exports = {
	networks: {
		development: {
			host: "127.0.0.1",
			port: 7545,
			network_id: "3",
			gas: 8000000,
			gasPrice: 1
		},
		live: {
			host: "0.0.0.0",
			port: 8545,
			network_id: "*",
			gas: 3000000
		}
	},
	rpc: {
		host: "0.0.0.0",
		port: 8545
	}
};
