-- gets latest connection status / timestamp of validator nodes
SELECT
    moniker,
    coalesce(validator_connections.version, 'NA') AS version,
    (CASE WHEN validator_connections.status IS NULL THEN 'disconnected' ELSE validator_connections.status END) as status,
    coalesce((CASE WHEN validator_connections.latest_conn_timestamp is NULL THEN (
        SELECT
            max(timestamp)
        FROM connections 
        WHERE connections.node_id in (
            SELECT
                node_id
            FROM nodes WHERE
            nodes.cons_address = validators.cons_address
        )
    )
    ELSE validator_connections.latest_conn_timestamp END), TO_TIMESTAMP('0000-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')) as latest_conn_timestamp
FROM validators LEFT JOIN (
SELECT
    cons_address,
    max(latest_timestamp) as latest_conn_timestamp,
    status,
    version
FROM (
    SELECT
        cons_address,
        nodes.node_id,
        latest_timestamp,
        status,
        version
    FROM nodes
    LEFT JOIN (
    SELECT
        node_id,
        max(timestamp) AS latest_timestamp
    FROM connections
    GROUP BY node_id
    ) AS latest_connections
    ON nodes.node_id = latest_connections.node_id
    LEFT JOIN connections
    ON nodes.node_id = connections.node_id
    AND timestamp = latest_timestamp
    ORDER BY cons_address
) as conn_data
WHERE status='connected'
GROUP BY cons_address, status, version
) AS validator_connections
ON validators.cons_address = validator_connections.cons_address;


-- populate winning / losing_bundles with timestamps that are populated in val_profits
UPDATE losing_bundles as lb
SET auction_timestamp = TO_TIMESTAMP(vp.timestamp, 'YYYY-MM-DD"T"HH24:MI:SS')
FROM val_profits as vp 
WHERE lb.height = vp.height;

UPDATE winning_bundles as wb
SET auction_timestamp = TO_TIMESTAMP(vp.timestamp, 'YYYY-MM-DD"T"HH24:MI:SS')
FROM val_profits as vp 
WHERE wb.height = vp.height;

-- populate nodes / validators
UPDATE validators 
SET registration_timestamp = coalesce((
    SELECT 
        min(ts.auction_timestamp)  
    FROM (
        SELECT 
            cons_address, 
            auction_timestamp 
        FROM losing_bundles UNION 
        SELECT 
            cons_address, 
            auction_timestamp 
        FROM winning_bundles
    ) AS ts WHERE 
    ts.cons_address = validators.cons_address), NOW()
);

-- update nodes table from registration timestamp in validators table
UPDATE nodes
SET registration_timestamp = validators.registration_timestamp
FROM validators
WHERE nodes.cons_address = validators.cons_address;
