import Foundation

enum CloudKitAccountsStoreMerge {
    static func applyingRemoteAccounts(_ remoteAccounts: [StoredAccount], to latestStore: AccountsStore) -> AccountsStore {
        applyingRemoteSnapshot(
            remoteAccounts,
            remoteSyncedAt: remoteAccounts.map(\.updatedAt).max() ?? 0,
            to: latestStore
        )
    }

    static func applyingRemoteSnapshot(
        _ remoteAccounts: [StoredAccount],
        remoteSyncedAt: Int64,
        to latestStore: AccountsStore
    ) -> AccountsStore {
        var mergedStore = latestStore
        let localAccountsByAccountID = Dictionary(
            uniqueKeysWithValues: latestStore.accounts.map { ($0.accountID, $0) }
        )
        var consumedAccountIDs = Set<String>()
        var mergedAccounts: [StoredAccount] = []
        mergedAccounts.reserveCapacity(max(latestStore.accounts.count, remoteAccounts.count))

        for remoteAccount in remoteAccounts {
            if let localAccount = localAccountsByAccountID[remoteAccount.accountID] {
                mergedAccounts.append(
                    mergeMatchedAccount(local: localAccount, remote: remoteAccount)
                )
                consumedAccountIDs.insert(remoteAccount.accountID)
            } else {
                mergedAccounts.append(remoteAccount)
            }
        }

        for localAccount in latestStore.accounts where !consumedAccountIDs.contains(localAccount.accountID) {
            if shouldKeepLocalOnlyAccount(localAccount, remoteSyncedAt: remoteSyncedAt) {
                mergedAccounts.append(localAccount)
            }
        }

        mergedStore.accounts = mergedAccounts
        return mergedStore
    }

    private static func mergeMatchedAccount(local: StoredAccount, remote: StoredAccount) -> StoredAccount {
        let metadataWinner = remote.updatedAt >= local.updatedAt ? remote : local
        let usageWinner = preferredUsageSource(local: local, remote: remote)

        var merged = metadataWinner
        merged.id = local.id
        merged.usage = usageWinner.usage
        merged.usageError = usageWinner.usageError
        merged.updatedAt = max(local.updatedAt, remote.updatedAt)
        return merged
    }

    private static func preferredUsageSource(local: StoredAccount, remote: StoredAccount) -> StoredAccount {
        let localUsageStamp = usageTimestamp(for: local)
        let remoteUsageStamp = usageTimestamp(for: remote)

        if remoteUsageStamp != localUsageStamp {
            return remoteUsageStamp > localUsageStamp ? remote : local
        }

        if remote.usage != local.usage {
            return remote.updatedAt >= local.updatedAt ? remote : local
        }

        if remote.usageError != local.usageError {
            return remote.updatedAt >= local.updatedAt ? remote : local
        }

        return local
    }

    private static func usageTimestamp(for account: StoredAccount) -> Int64 {
        if let fetchedAt = account.usage?.fetchedAt {
            return fetchedAt
        }
        if account.usageError != nil {
            return account.updatedAt
        }
        return 0
    }

    private static func shouldKeepLocalOnlyAccount(
        _ localAccount: StoredAccount,
        remoteSyncedAt: Int64
    ) -> Bool {
        localAccount.updatedAt > remoteSyncedAt
    }
}

enum CloudKitSelectionMerge {
    static func shouldApplyRemoteSelection(
        _ remoteSelection: CurrentAccountSelection,
        over localSelection: CurrentAccountSelection?
    ) -> Bool {
        guard let localSelection else { return true }
        return comparesNewer(remoteSelection, than: localSelection)
    }

    static func shouldKeepServerSelection(
        _ serverSelection: CurrentAccountSelection,
        over localSelection: CurrentAccountSelection
    ) -> Bool {
        serverSelection == localSelection || comparesNewer(serverSelection, than: localSelection)
    }

    private static func comparesNewer(
        _ lhs: CurrentAccountSelection,
        than rhs: CurrentAccountSelection
    ) -> Bool {
        if lhs.selectedAt != rhs.selectedAt {
            return lhs.selectedAt > rhs.selectedAt
        }
        if lhs.sourceDeviceID != rhs.sourceDeviceID {
            return lhs.sourceDeviceID > rhs.sourceDeviceID
        }
        return lhs.accountID > rhs.accountID
    }
}
