-- DATABASE INITIALIZATION -----------------------------------------------------
--
-- The following code performs the initial setup of the PostgreSQL database with
-- required objects for the anchor database.
--
--------------------------------------------------------------------------------
-- create schema
CREATE SCHEMA IF NOT EXISTS public;
-- set schema search path
SET search_path = public;
-- KNOTS --------------------------------------------------------------------------------------------------------------
--
-- Knots are used to store finite sets of values, normally used to describe states
-- of entities (through knotted attributes) or relationships (through knotted ties).
-- Knots have their own surrogate identities and are therefore immutable.
-- Values can be added to the set over time though.
-- Knots should have values that are mutually exclusive and exhaustive.
-- Knots are unfolded when using equivalence.
--
-- ANCHORS AND ATTRIBUTES ---------------------------------------------------------------------------------------------
--
-- Anchors are used to store the identities of entities.
-- Anchors are immutable.
-- Attributes are used to store values for properties of entities.
-- Attributes are mutable, their values may change over one or more types of time.
-- Attributes have four flavors: static, historized, knotted static, and knotted historized.
-- Anchors may have zero or more adjoined attributes.
--
-- Anchor table -------------------------------------------------------------------------------------------------------
-- CA_categories table (with 2 attributes)
-----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.CA_categories (
    CA_ID integer generated by default as identity not null,
    Metadata_CA integer not null, 
    constraint pkCA_categories primary key (
        CA_ID 
    )
);
-- Static attribute table ---------------------------------------------------------------------------------------------
-- CA_CAN_categories_category_name table (on CA_categories)
-----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.CA_CAN_categories_category_name (
    CA_CAN_CA_ID integer not null,
    CA_CAN_categories_category_name VARCHAR(100) not null,
    Metadata_CA_CAN integer not null,
    constraint fkCA_CAN_categories_category_name foreign key (
        CA_CAN_CA_ID
    ) references public.CA_categories (CA_ID),
    constraint pkCA_CAN_categories_category_name primary key (
        CA_CAN_CA_ID 
    ) include (
        CA_CAN_categories_category_name
    )
);
-- Static attribute table ---------------------------------------------------------------------------------------------
-- CA_CAI_categories_category_id table (on CA_categories)
-----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.CA_CAI_categories_category_id (
    CA_CAI_CA_ID integer not null,
    CA_CAI_categories_category_id SERIAL not null,
    Metadata_CA_CAI integer not null,
    constraint fkCA_CAI_categories_category_id foreign key (
        CA_CAI_CA_ID
    ) references public.CA_categories (CA_ID),
    constraint pkCA_CAI_categories_category_id primary key (
        CA_CAI_CA_ID 
    ) include (
        CA_CAI_categories_category_id
    )
);
-- Anchor table -------------------------------------------------------------------------------------------------------
-- PR_products table (with 0 attributes)
-----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.PR_products (
    PR_ID integer generated by default as identity not null,
    Metadata_PR integer not null, 
    constraint pkPR_products primary key (
        PR_ID 
    )
);
-- TIES ---------------------------------------------------------------------------------------------------------------
--
-- Ties are used to represent relationships between entities.
-- They come in four flavors: static, historized, knotted static, and knotted historized.
-- Ties have cardinality, constraining how members may participate in the relationship.
-- Every entity that is a member in a tie has a specified role in the relationship.
-- Ties must have at least two anchor roles and zero or more knot roles.
--
-- Static tie table ---------------------------------------------------------------------------------------------------
-- CA_cat_id_PR_cat_id2 table (having 2 roles)
-----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.CA_cat_id_PR_cat_id2 (
    CA_ID_cat_id integer not null, 
    PR_ID_cat_id2 integer not null, 
    Metadata_CA_cat_id_PR_cat_id2 integer not null,
    constraint CA_cat_id_PR_cat_id2_fkCA_cat_id foreign key (
        CA_ID_cat_id
    ) references public.CA_categories(CA_ID), 
    constraint CA_cat_id_PR_cat_id2_fkPR_cat_id2 foreign key (
        PR_ID_cat_id2
    ) references public.PR_products(PR_ID), 
    constraint pkCA_cat_id_PR_cat_id2 primary key (
        PR_ID_cat_id2 
    )
);
-- KNOT EQUIVALENCE VIEWS ---------------------------------------------------------------------------------------------
--
-- Equivalence views combine the identity and equivalent parts of a knot into a single view, making
-- it look and behave like a regular knot. They also make it possible to retrieve data for only the
-- given equivalent.
--
-- @equivalent the equivalent that you want to retrieve data for
--
-- ATTRIBUTE EQUIVALENCE VIEWS ----------------------------------------------------------------------------------------
--
-- Equivalence views of attributes make it possible to retrieve data for only the given equivalent.
--
-- @equivalent the equivalent that you want to retrieve data for
--
-- KEY GENERATORS -----------------------------------------------------------------------------------------------------
--
-- These stored procedures can be used to generate identities of entities.
-- Corresponding anchors must have an incrementing identity column.
--
-- Key Generation Stored Procedure ------------------------------------------------------------------------------------
-- kCA_categories identity by surrogate key generation stored procedure
-----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.kCA_categories(
    requestedNumberOfIdentities bigint,
    metadata integer
) RETURNS void AS '
    BEGIN
        IF requestedNumberOfIdentities > 0
        THEN
            INSERT INTO public.CA_categories (
                Metadata_CA
            )
            SELECT
                metadata
            FROM
                generate_series(1,requestedNumberOfIdentities);
        END IF;
    END;
' LANGUAGE plpgsql
;
-- Key Generation Stored Procedure ------------------------------------------------------------------------------------
-- kPR_products identity by surrogate key generation stored procedure
-----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.kPR_products(
    requestedNumberOfIdentities bigint,
    metadata integer
) RETURNS void AS '
    BEGIN
        IF requestedNumberOfIdentities > 0
        THEN
            INSERT INTO public.PR_products (
                Metadata_PR
            )
            SELECT
                metadata
            FROM
                generate_series(1,requestedNumberOfIdentities);
        END IF;
    END;
' LANGUAGE plpgsql
;
-- ATTRIBUTE TEMPORAL PERSPECTIVES ---------------------------------------------------------------------------------------
--
-- These table valued functions simplify temporal querying by providing a temporal
-- perspective of each attribute. There are three types of perspectives: latest,
-- point-in-time and now. 
--
-- The latest perspective shows the latest available information for each attribute.
-- The now perspective shows the information as it is right now.
-- The point-in-time perspective lets you travel through the information to the given timepoint.
--
-- @changingTimepoint the point in changing time to travel to
--
-- Under equivalence all these views default to equivalent = 0, however, corresponding
-- prepended-e perspectives are provided in order to select a specific equivalent.
--
-- @equivalent the equivalent for which to retrieve data
--
-- ANCHOR TEMPORAL PERSPECTIVES ---------------------------------------------------------------------------------------
--
-- These table valued functions simplify temporal querying by providing a temporal
-- perspective of each anchor. There are four types of perspectives: latest,
-- point-in-time, difference, and now. They also denormalize the anchor, its attributes,
-- and referenced knots from sixth to third normal form.
--
-- The latest perspective shows the latest available information for each anchor.
-- The now perspective shows the information as it is right now.
-- The point-in-time perspective lets you travel through the information to the given timepoint.
--
-- @changingTimepoint the point in changing time to travel to
--
-- The difference perspective shows changes between the two given timepoints, and for
-- changes in all or a selection of attributes.
--
-- @intervalStart the start of the interval for finding changes
-- @intervalEnd the end of the interval for finding changes
-- @selection a list of mnemonics for tracked attributes, ie 'MNE MON ICS', or null for all
--
-- Under equivalence all these views default to equivalent = 0, however, corresponding
-- prepended-e perspectives are provided in order to select a specific equivalent.
--
-- @equivalent the equivalent for which to retrieve data
--
-- Latest perspective -------------------------------------------------------------------------------------------------
-- lCA_categories viewed by the latest available information (may include future versions)
-----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.lCA_categories AS
SELECT CA.CA_ID
     , CA.Metadata_CA
     , CAN.CA_CAN_CA_ID
     , CAN.Metadata_CA_CAN
     , CAN.CA_CAN_categories_category_name
     , CAI.CA_CAI_CA_ID
     , CAI.Metadata_CA_CAI
     , CAI.CA_CAI_categories_category_id
  FROM public.CA_categories CA
  LEFT 
  JOIN public.CA_CAN_categories_category_name CAN
    ON CAN.CA_CAN_CA_ID = CA.CA_ID
  LEFT 
  JOIN public.CA_CAI_categories_category_id CAI
    ON CAI.CA_CAI_CA_ID = CA.CA_ID;
;
-- Point-in-time perspective ------------------------------------------------------------------------------------------
-- pCA_categories viewed as it was on the given timepoint
-----------------------------------------------------------------------------------------------------------------------
 CREATE OR REPLACE FUNCTION public.pCA_categories 
      ( changingTimepoint timestamp
      )
RETURNS TABLE 
      ( CA_ID integer
      , Metadata_CA integer
      , CA_CAN_CA_ID integer
      , Metadata_CA_CAN integer
      , CA_CAN_categories_category_name VARCHAR(100)
      , CA_CAI_CA_ID integer
      , Metadata_CA_CAI integer
      , CA_CAI_categories_category_id SERIAL
      ) 
AS 
'
 SELECT CA.CA_ID
      , CA.Metadata_CA
      , CAN.CA_CAN_CA_ID
      , CAN.Metadata_CA_CAN
      , CAN.CA_CAN_categories_category_name
      , CAI.CA_CAI_CA_ID
      , CAI.Metadata_CA_CAI
      , CAI.CA_CAI_categories_category_id
   FROM public.CA_categories CA
   LEFT 
   JOIN public.CA_CAN_categories_category_name CAN
     ON CAN.CA_CAN_CA_ID = CA.CA_ID
   LEFT 
   JOIN public.CA_CAI_categories_category_id CAI
     ON CAI.CA_CAI_CA_ID = CA.CA_ID;
' 
LANGUAGE SQL STABLE
;
-- Now perspective ----------------------------------------------------------------------------------------------------
-- nCA_categories viewed as it currently is (cannot include future versions)
-----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.nCA_categories
AS
SELECT *
  FROM public.pCA_categories(current_timestamp::timestamp)
;
-- SCHEMA EVOLUTION ---------------------------------------------------------------------------------------------------
--
-- The following tables, views, and functions are used to track schema changes
-- over time, as well as providing every XML that has been 'executed' against
-- the database.
--
-- Schema table -------------------------------------------------------------------------------------------------------
-- The schema table holds every xml that has been executed against the database
-----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public._Schema 
     ( version int generated by default as identity primary key
     , activation timestamp not null
     , schema jsonb not null
     )
;
-- Insert the JSON schema (as of now)
INSERT INTO public._Schema 
     ( activation
     , schema
     )
SELECT current_timestamp
     , '{
   "schema": {
      "format": "0.99.11",
      "date": "2023-10-24",
      "time": "00:43:30",
      "metadata": {
         "changingRange": "timestamp",
         "encapsulation": "public",
         "identity": "integer",
         "metadataPrefix": "Metadata",
         "metadataType": "integer",
         "metadataUsage": "true",
         "changingSuffix": "ChangedAt",
         "identitySuffix": "ID",
         "positIdentity": "integer",
         "positGenerator": "true",
         "positingRange": "timestamp",
         "positingSuffix": "PositedAt",
         "positorRange": "smallint",
         "positorSuffix": "Positor",
         "reliabilityRange": "decimal(5,2)",
         "reliabilitySuffix": "Reliability",
         "defaultReliability": "1",
         "deleteReliability": "0",
         "assertionSuffix": "Assertion",
         "partitioning": "false",
         "entityIntegrity": "true",
         "restatability": "true",
         "idempotency": "false",
         "assertiveness": "true",
         "naming": "improved",
         "positSuffix": "Posit",
         "annexSuffix": "Annex",
         "chronon": "timestamp",
         "now": "current_timestamp",
         "dummySuffix": "Dummy",
         "versionSuffix": "Version",
         "statementTypeSuffix": "StatementType",
         "checksumSuffix": "Checksum",
         "businessViews": "false",
         "decisiveness": "true",
         "equivalence": "false",
         "equivalentSuffix": "EQ",
         "equivalentRange": "smallint",
         "databaseTarget": "PostgreSQL",
         "temporalization": "uni",
         "deletability": "false",
         "deletablePrefix": "Deletable",
         "deletionSuffix": "Deleted",
         "privacy": "Ignore",
         "checksum": "false",
         "triggers": "true",
         "knotAliases": "false"
      },
      "anchor": {
         "CA": {
            "id": "CA",
            "mnemonic": "CA",
            "descriptor": "categories",
            "identity": "integer",
            "metadata": {
               "capsule": "public",
               "generator": "true"
            },
            "attribute": {
               "CAN": {
                  "id": "CAN",
                  "mnemonic": "CAN",
                  "descriptor": "category_name",
                  "dataRange": "VARCHAR(100)",
                  "metadata": {
                     "privacy": "Ignore",
                     "capsule": "public",
                     "idempotent": "false",
                     "deletable": "false"
                  },
                  "layout": {
                     "x": "863.19",
                     "y": "379.63",
                     "fixed": "false"
                  }
               },
               "CAI": {
                  "id": "CAI",
                  "mnemonic": "CAI",
                  "descriptor": "category_id",
                  "dataRange": "SERIAL",
                  "metadata": {
                     "privacy": "Ignore",
                     "capsule": "public",
                     "idempotent": "false",
                     "deletable": "false"
                  },
                  "layout": {
                     "x": "777.78",
                     "y": "386.56",
                     "fixed": "true"
                  }
               }
            },
            "attributes": [
               "CAN",
               "CAI"
            ],
            "layout": {
               "x": "830.78",
               "y": "329.14",
               "fixed": "true"
            }
         },
         "PR": {
            "id": "PR",
            "mnemonic": "PR",
            "descriptor": "products",
            "identity": "integer",
            "metadata": {
               "capsule": "public",
               "generator": "true"
            },
            "layout": {
               "x": "964.75",
               "y": "250.38",
               "fixed": "true"
            }
         }
      },
      "anchors": [
         "CA",
         "PR"
      ],
      "tie": {
         "CA_cat_id_PR_cat_id2": {
            "id": "CA_cat_id_PR_cat_id2",
            "anchorRole": {
               "CA_cat_id": {
                  "id": "CA_cat_id",
                  "role": "cat_id",
                  "type": "CA",
                  "identifier": "false"
               },
               "PR_cat_id2": {
                  "id": "PR_cat_id2",
                  "role": "cat_id2",
                  "type": "PR",
                  "identifier": "true"
               }
            },
            "roles": [
               "CA_cat_id",
               "PR_cat_id2"
            ],
            "metadata": {
               "capsule": "public",
               "deletable": "false",
               "idempotent": "false"
            },
            "layout": {
               "x": "899.51",
               "y": "282.97",
               "fixed": "false"
            }
         }
      },
      "ties": [
         "CA_cat_id_PR_cat_id2"
      ]
   }
}'
;
-- Schema expanded view -----------------------------------------------------------------------------------------------
-- A view of the schema table that expands the XML attributes into columns
-----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public._Schema_Expanded 
AS
SELECT version
     , activation
     , (schema -> 'schema' ->> 'format') as format
     , (schema -> 'schema' ->> 'date')::date as date
     , (schema -> 'schema' ->> 'time')::time as time
     , (schema -> 'schema' -> 'metadata' ->> 'temporalization') as temporalization
     , (schema -> 'schema' -> 'metadata' ->> 'databaseTarget') as databaseTarget	
     , (schema -> 'schema' -> 'metadata' ->> 'changingRange') as changingRange
     , (schema -> 'schema' -> 'metadata' ->> 'encapsulation') as encapsulation
     , (schema -> 'schema' -> 'metadata' ->> 'identity') as identity
     , (schema -> 'schema' -> 'metadata' ->> 'metadataPrefix') as metadataPrefix
     , (schema -> 'schema' -> 'metadata' ->> 'metadataType') as metadataType
     , (schema -> 'schema' -> 'metadata' ->> 'metadataUsage') as metadataUsage	
     , (schema -> 'schema' -> 'metadata' ->> 'changingSuffix') as changingSuffix
     , (schema -> 'schema' -> 'metadata' ->> 'identitySuffix') as identitySuffix
     , (schema -> 'schema' -> 'metadata' ->> 'positIdentity') as positIdentity
     , (schema -> 'schema' -> 'metadata' ->> 'positGenerator') as positGenerator	
     , (schema -> 'schema' -> 'metadata' ->> 'positingRange') as positingRange
     , (schema -> 'schema' -> 'metadata' ->> 'positingSuffix') as positingSuffix	
     , (schema -> 'schema' -> 'metadata' ->> 'positorRange') as positorRange
     , (schema -> 'schema' -> 'metadata' ->> 'positorSuffix') as positorSuffix
     , (schema -> 'schema' -> 'metadata' ->> 'reliabilityRange') as reliabilityRange
     , (schema -> 'schema' -> 'metadata' ->> 'reliabilitySuffix') as reliabilitySuffix
     , (schema -> 'schema' -> 'metadata' ->> 'reliableCutoff') as reliableCutoff
     , (schema -> 'schema' -> 'metadata' ->> 'deleteReliability') as deleteReliability	
     , (schema -> 'schema' -> 'metadata' ->> 'reliableSuffix') as reliableSuffix
     , (schema -> 'schema' -> 'metadata' ->> 'partitioning') as partitioning
     , (schema -> 'schema' -> 'metadata' ->> 'entityIntegrity') as entityIntegrity
     , (schema -> 'schema' -> 'metadata' ->> 'restatability') as restatability
     , (schema -> 'schema' -> 'metadata' ->> 'idempotency') as idempotency
     , (schema -> 'schema' -> 'metadata' ->> 'assertiveness') as assertiveness	
     , (schema -> 'schema' -> 'metadata' ->> 'naming') as naming
     , (schema -> 'schema' -> 'metadata' ->> 'positSuffix') as positSuffix	
     , (schema -> 'schema' -> 'metadata' ->> 'annexSuffix') as annexSuffix
     , (schema -> 'schema' -> 'metadata' ->> 'chronon') as chronon
     , (schema -> 'schema' -> 'metadata' ->> 'now') as now
     , (schema -> 'schema' -> 'metadata' ->> 'dummySuffix') as dummySuffix
     , (schema -> 'schema' -> 'metadata' ->> 'statementTypeSuffix') as statementTypeSuffix
     , (schema -> 'schema' -> 'metadata' ->> 'checksumSuffix') as checksumSuffix	
     , (schema -> 'schema' -> 'metadata' ->> 'businessViews') as businessViews
     , (schema -> 'schema' -> 'metadata' ->> 'equivalence') as equivalence
     , (schema -> 'schema' -> 'metadata' ->> 'equivalentSuffix') as equivalentSuffix
     , (schema -> 'schema' -> 'metadata' ->> 'equivalentRange') as equivalentRange	
  FROM public._Schema
;
-- Anchor view --------------------------------------------------------------------------------------------------------
-- The anchor view shows information about all the anchors in a schema
-----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public._Anchor
AS
SELECT s.version
     , s.activation
     , s.schema -> 'schema' -> 'metadata' ->> 'temporalization' as temporalization	
     , a.key || '_' || v.descriptor as name
     , v.descriptor	
     , a.key as mnemonic	
     , v.metadata ->> 'capsule' as capsule
     , v.identity
     , v.metadata ->> 'generator' as generator
     , coalesce(cardinality(v.attributes),0) as numberOfAttributes
  FROM public._schema as s
     , jsonb_each(s.schema -> 'schema' -> 'anchor') as a
     , jsonb_to_record(a.value) as v(descriptor text, identity text, "dataRange" text, metadata jsonb, attributes text[])
;	
-- Knot view ----------------------------------------------------------------------------------------------------------
-- The knot view shows information about all the knots in a schema
-----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public._Knot
AS
SELECT s.version
     , s.activation
     , s.schema -> 'schema' -> 'metadata' ->> 'temporalization' as temporalization	
     , k.key || '_' || v.descriptor as name	
     , v.descriptor
     , k.key as mnemonic	
     , v.metadata ->> 'capsule' as capsule
     , v."dataRange" as datarange	
     , v.identity
     , v.metadata ->> 'generator' as generator
     , coalesce(v.metadata ->> 'checksum','false') as checksum
     , v.description	
     , coalesce(v.metadata ->> 'equivalent','false') as equivalent
  FROM public._schema as s
     , jsonb_each(s.schema -> 'schema' -> 'knot') as k
     , jsonb_to_record(k.value) as v(descriptor text, identity text, "dataRange" text, description text, metadata jsonb)
;
-- Attribute view -----------------------------------------------------------------------------------------------------
-- The attribute view shows information about all the attributes in a schema
-----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public._Attribute
AS
SELECT s.version
     , s.activation
     , s.schema -> 'schema' -> 'metadata' ->> 'temporalization' as temporalization	
     , a.key || '_' || t.key || '_' || (a.value ->> 'descriptor') || '_' || v.descriptor as name
     , v.descriptor 
     , t.key as mnemonic 
     , v.metadata ->> 'capsule' as capsule
     , v."dataRange" as dataRange
     , case when v."knotRange" is null then false else true end as knotted
     , v."knotRange" as knotRange
     , case when v."timeRange" is null then false else true end as historized 
     , v."timeRange" as timeRange 
     , v.metadata ->> 'generator' as generator 
     , v.metadata ->> 'assertive' as assertive 
     , v.metadata ->> 'privacy' as privacy
     , coalesce(v.metadata ->> 'checksum','false') as checksum 
     , coalesce(v.metadata ->> 'equivalent','false') as equivalent
     , v.metadata ->> 'restatable' as restatable 
     , v.metadata ->> 'idempotent' as idempotent 
     , a.key as anchorMnemonic
     , (a.value ->> 'descriptor') as anchorDescriptor
     , (a.value ->> 'identity') as anchorIdentity
     , v.metadata ->> 'deletable' as deletable
     , v.metadata ->> 'encryptionGroup' as encryptionGroup
     , v.description
     , coalesce(cardinality(v.keys),0) as numberKeyOfStops
  FROM public._schema as s
     , jsonb_each(s.schema -> 'schema' -> 'anchor') as a
     , jsonb_each(a.value -> 'attribute') as t
     , jsonb_to_record(t.value) as v(descriptor text, identity text, "dataRange" text, "knotRange" text, "timeRange" text, description text, metadata jsonb, keys text[]) 
;
-- Tie view -----------------------------------------------------------------------------------------------------------
-- The tie view shows information about all the ties in a schema
-----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public._Tie
AS
SELECT s.version
     , s.activation
     , s.schema -> 'schema' -> 'metadata' ->> 'temporalization' as temporalization	
     , t.key as name
     , v.metadata ->> 'capsule' as capsule	
     , case when v."timeRange" is null then false else true end as historized 
     , v."timeRange" as timeRange
     , cardinality(roles) as numberOfRoles
     , array(select value ->> 'role' from jsonb_each(v."anchorRole")) || array(select value ->> 'role' from jsonb_each(v."knotRole")) as roles
     , cardinality(array(select jsonb_object_keys(v."anchorRole"))) as numberOfAnchors
     , array(select split_part(jsonb_object_keys(v."anchorRole"),'_',1)) as anchors
     , coalesce(cardinality(array(select jsonb_object_keys(v."knotRole")))) as numberOfKnots
     , array(select split_part(jsonb_object_keys(v."knotRole"),'_',1)) as knots	
     --, v."anchorRole"
     , cardinality(array(select value ->> 'identifier' from jsonb_each(v."anchorRole") where value ->> 'identifier' = 'true') || array(select value ->> 'identifier' from jsonb_each(v."knotRole") where value ->> 'identifier' = 'true')) as identifiers
     , v.metadata ->> 'generator' as generator 
     , v.metadata ->> 'assertive' as assertive 
     , v.metadata ->> 'restatable' as restatable 
     , v.metadata ->> 'idempotent' as idempotent 
  FROM public._schema as s
     , jsonb_each(s.schema -> 'schema' -> 'tie') as t
     , jsonb_to_record(t.value) as v("timeRange" text, roles text[], metadata jsonb, "anchorRole" jsonb, "knotRole" jsonb)
;