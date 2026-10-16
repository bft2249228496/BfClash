package com.bfclash.client.service.modules

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flow

@OptIn(ExperimentalCoroutinesApi::class)
internal fun <T> screenOnUpdates(screenOn: Flow<Boolean>, values: Flow<T>): Flow<T> =
    screenOn.distinctUntilChanged().flatMapLatest { interactive ->
        if (!interactive) {
            emptyFlow()
        } else {
            combine(
                flow {
                    emit(Unit)
                    while (true) {
                        delay(1_000)
                        emit(Unit)
                    }
                },
                values,
            ) { _, value -> value }
        }
    }
