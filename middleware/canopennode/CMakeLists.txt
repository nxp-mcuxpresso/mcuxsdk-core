# This is NXP version of CANopenNode CMakeLists.txt

if (CONFIG_MCUX_COMPONENT_middleware.canopennode)
    mcux_add_include(
        PROJECT_BASE_PATH canopennode
        INCLUDES port
                 protocol
    )

    mcux_add_source(
        SOURCES
            protocol/CANopen.c
            protocol/CANopen.h
    )

if (CONFIG_MCUX_COMPONENT_middleware.canopennode.301)
    mcux_add_include(
        PROJECT_BASE_PATH canopennode
        INCLUDES protocol/301
    )
    mcux_add_source(
        SOURCES
            protocol/301/CO_Emergency.c
            protocol/301/CO_Emergency.h
            protocol/301/CO_HBconsumer.c
            protocol/301/CO_HBconsumer.h
            protocol/301/CO_NMT_Heartbeat.c
            protocol/301/CO_NMT_Heartbeat.h
            protocol/301/CO_ODinterface.c
            protocol/301/CO_ODinterface.h
            protocol/301/CO_PDO.c
            protocol/301/CO_PDO.h
            protocol/301/CO_SDOclient.c
            protocol/301/CO_SDOclient.h
            protocol/301/CO_SDOserver.c
            protocol/301/CO_SDOserver.h
            protocol/301/CO_SYNC.c
            protocol/301/CO_SYNC.h
            protocol/301/CO_TIME.c
            protocol/301/CO_TIME.h
            protocol/301/CO_config.h
            protocol/301/CO_driver.h
            protocol/301/CO_fifo.c
            protocol/301/CO_fifo.h
            protocol/301/crc16-ccitt.c
            protocol/301/crc16-ccitt.h
    )
endif ()

if (CONFIG_MCUX_COMPONENT_middleware.canopennode.303)
    mcux_add_include(
        PROJECT_BASE_PATH canopennode
        INCLUDES protocol/303
    )
    mcux_add_source(
        SOURCES
            protocol/303/CO_LEDs.c
            protocol/303/CO_LEDs.h
    )
endif ()

if (CONFIG_MCUX_COMPONENT_middleware.canopennode.304)
    mcux_add_include(
        PROJECT_BASE_PATH canopennode
        INCLUDES protocol/304
    )
    mcux_add_source(
        SOURCES
            protocol/304/CO_GFC.c
            protocol/304/CO_GFC.h
            protocol/304/CO_SRDO.c
            protocol/304/CO_SRDO.h
    )
endif ()

if (CONFIG_MCUX_COMPONENT_middleware.canopennode.305)
    mcux_add_include(
        PROJECT_BASE_PATH canopennode
        INCLUDES protocol/305
    )
    mcux_add_source(
        SOURCES
            protocol/305/CO_LSS.h
            protocol/305/CO_LSSmaster.c
            protocol/305/CO_LSSmaster.h
            protocol/305/CO_LSSslave.c
            protocol/305/CO_LSSslave.h
    )
endif ()

if (CONFIG_MCUX_COMPONENT_middleware.canopennode.309)
    mcux_add_include(
        PROJECT_BASE_PATH canopennode
        INCLUDES protocol/309
    )
    mcux_add_source(
        SOURCES
            protocol/309/CO_gateway_ascii.c
            protocol/309/CO_gateway_ascii.h
    )
endif ()

if (CONFIG_MCUX_COMPONENT_middleware.canopennode.extra)
    mcux_add_include(
        PROJECT_BASE_PATH canopennode
        INCLUDES protocol/extra
    )
    mcux_add_source(
        SOURCES
            protocol/extra/CO_trace.c
            protocol/extra/CO_trace.h
    )
endif ()

if (CONFIG_MCUX_COMPONENT_middleware.canopennode.storage)
    mcux_add_include(
        PROJECT_BASE_PATH canopennode
        INCLUDES protocol/storage
    )
    mcux_add_source(
        SOURCES
            protocol/storage/CO_eeprom.h
            protocol/storage/CO_storage.c
            protocol/storage/CO_storage.h
            protocol/storage/CO_storageEeprom.c
            protocol/storage/CO_storageEeprom.h
    )
endif ()

endif ()
