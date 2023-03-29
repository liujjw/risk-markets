// @ts-check
import { initSchema } from '@aws-amplify/datastore';
import { schema } from './schema';



const { EthereumAccount, User } = initSchema(schema);

export {
  EthereumAccount,
  User
};