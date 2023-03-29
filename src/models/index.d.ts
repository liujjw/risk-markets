import { ModelInit, MutableModel, __modelMeta__, ManagedIdentifier } from "@aws-amplify/datastore";
// @ts-ignore
import { LazyLoading, LazyLoadingDisabled, AsyncCollection } from "@aws-amplify/datastore";





type EagerEthereumAccount = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<EthereumAccount, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly public_key?: string | null;
  readonly userID: string;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

type LazyEthereumAccount = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<EthereumAccount, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly public_key?: string | null;
  readonly userID: string;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

export declare type EthereumAccount = LazyLoading extends LazyLoadingDisabled ? EagerEthereumAccount : LazyEthereumAccount

export declare const EthereumAccount: (new (init: ModelInit<EthereumAccount>) => EthereumAccount) & {
  copyOf(source: EthereumAccount, mutator: (draft: MutableModel<EthereumAccount>) => MutableModel<EthereumAccount> | void): EthereumAccount;
}

type EagerUser = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<User, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly username?: string | null;
  readonly password?: string | null;
  readonly EthereumAccounts?: (EthereumAccount | null)[] | null;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

type LazyUser = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<User, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly username?: string | null;
  readonly password?: string | null;
  readonly EthereumAccounts: AsyncCollection<EthereumAccount>;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

export declare type User = LazyLoading extends LazyLoadingDisabled ? EagerUser : LazyUser

export declare const User: (new (init: ModelInit<User>) => User) & {
  copyOf(source: User, mutator: (draft: MutableModel<User>) => MutableModel<User> | void): User;
}