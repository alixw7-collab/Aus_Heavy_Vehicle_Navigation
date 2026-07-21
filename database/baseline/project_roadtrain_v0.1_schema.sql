--
-- PostgreSQL database dump
--

\restrict R67Whw9gsyCA0hBGBRxoGXvd5R0Mtgc8OrmIC0KwBp2aoHdKBlyV4Izi6mP4yrL

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

-- Started on 2026-07-21 16:11:07

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 7 (class 2615 OID 31523)
-- Name: hvn; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA hvn;


ALTER SCHEMA hvn OWNER TO postgres;

--
-- TOC entry 2 (class 3079 OID 30435)
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- TOC entry 5971 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 231 (class 1259 OID 31558)
-- Name: road_access; Type: TABLE; Schema: hvn; Owner: postgres
--

CREATE TABLE hvn.road_access (
    access_id bigint NOT NULL,
    segment_id bigint NOT NULL,
    vehicle_id bigint NOT NULL,
    access_status character varying(20) NOT NULL,
    access_direction character varying(10) DEFAULT 'BOTH'::character varying NOT NULL,
    mass_scheme character varying(20),
    permit_required boolean DEFAULT false NOT NULL,
    conditions_text text,
    source_authority character varying(100),
    source_network character varying(200),
    source_reference text,
    effective_from date,
    effective_to date,
    verified_at timestamp with time zone,
    confidence_status character varying(20) DEFAULT 'OFFICIAL'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    source_id bigint,
    CONSTRAINT road_access_direction_check CHECK (((access_direction)::text = ANY ((ARRAY['BOTH'::character varying, 'FORWARD'::character varying, 'REVERSE'::character varying])::text[]))),
    CONSTRAINT road_access_status_check CHECK (((access_status)::text = ANY ((ARRAY['APPROVED'::character varying, 'CONDITIONAL'::character varying, 'PERMIT'::character varying, 'PROHIBITED'::character varying, 'UNKNOWN'::character varying])::text[])))
);


ALTER TABLE hvn.road_access OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 31557)
-- Name: road_access_access_id_seq; Type: SEQUENCE; Schema: hvn; Owner: postgres
--

ALTER TABLE hvn.road_access ALTER COLUMN access_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME hvn.road_access_access_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 233 (class 1259 OID 31592)
-- Name: road_rule_source; Type: TABLE; Schema: hvn; Owner: postgres
--

CREATE TABLE hvn.road_rule_source (
    source_id bigint NOT NULL,
    authority character varying(100) NOT NULL,
    document_name character varying(250),
    version character varying(50),
    publication_date date,
    effective_date date,
    expiry_date date,
    document_url text,
    confidence_level character varying(30),
    notes text,
    retrieved_at timestamp with time zone
);


ALTER TABLE hvn.road_rule_source OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 31591)
-- Name: road_rule_source_source_id_seq; Type: SEQUENCE; Schema: hvn; Owner: postgres
--

ALTER TABLE hvn.road_rule_source ALTER COLUMN source_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME hvn.road_rule_source_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 229 (class 1259 OID 31541)
-- Name: road_segment; Type: TABLE; Schema: hvn; Owner: postgres
--

CREATE TABLE hvn.road_segment (
    segment_id bigint NOT NULL,
    source_dataset character varying(50) NOT NULL,
    source_feature_id character varying(100),
    road_name character varying(200),
    road_class character varying(50),
    direction_code character varying(10) DEFAULT 'BOTH'::character varying NOT NULL,
    length_m numeric(12,2),
    source_updated date,
    imported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    active boolean DEFAULT true NOT NULL,
    geometry public.geometry(LineString,7856)
);


ALTER TABLE hvn.road_segment OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 31540)
-- Name: road_segment_segment_id_seq; Type: SEQUENCE; Schema: hvn; Owner: postgres
--

ALTER TABLE hvn.road_segment ALTER COLUMN segment_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME hvn.road_segment_segment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 227 (class 1259 OID 31525)
-- Name: vehicle_configuration; Type: TABLE; Schema: hvn; Owner: postgres
--

CREATE TABLE hvn.vehicle_configuration (
    vehicle_id bigint NOT NULL,
    vehicle_code character varying(30) NOT NULL,
    vehicle_name character varying(100) NOT NULL,
    combination_family character varying(50) NOT NULL,
    overall_length_m numeric(5,2),
    overall_height_m numeric(4,2),
    overall_width_m numeric(4,2),
    operating_mass_t numeric(6,2),
    mass_scheme character varying(20),
    pbs_level character varying(20),
    active boolean DEFAULT true NOT NULL,
    notes text
);


ALTER TABLE hvn.vehicle_configuration OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 31524)
-- Name: vehicle_configuration_vehicle_id_seq; Type: SEQUENCE; Schema: hvn; Owner: postgres
--

ALTER TABLE hvn.vehicle_configuration ALTER COLUMN vehicle_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME hvn.vehicle_configuration_vehicle_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 5806 (class 2606 OID 31578)
-- Name: road_access road_access_pkey; Type: CONSTRAINT; Schema: hvn; Owner: postgres
--

ALTER TABLE ONLY hvn.road_access
    ADD CONSTRAINT road_access_pkey PRIMARY KEY (access_id);


--
-- TOC entry 5810 (class 2606 OID 31600)
-- Name: road_rule_source road_rule_source_pkey; Type: CONSTRAINT; Schema: hvn; Owner: postgres
--

ALTER TABLE ONLY hvn.road_rule_source
    ADD CONSTRAINT road_rule_source_pkey PRIMARY KEY (source_id);


--
-- TOC entry 5804 (class 2606 OID 31555)
-- Name: road_segment road_segment_pkey; Type: CONSTRAINT; Schema: hvn; Owner: postgres
--

ALTER TABLE ONLY hvn.road_segment
    ADD CONSTRAINT road_segment_pkey PRIMARY KEY (segment_id);


--
-- TOC entry 5799 (class 2606 OID 31537)
-- Name: vehicle_configuration vehicle_configuration_pkey; Type: CONSTRAINT; Schema: hvn; Owner: postgres
--

ALTER TABLE ONLY hvn.vehicle_configuration
    ADD CONSTRAINT vehicle_configuration_pkey PRIMARY KEY (vehicle_id);


--
-- TOC entry 5801 (class 2606 OID 31539)
-- Name: vehicle_configuration vehicle_configuration_vehicle_code_key; Type: CONSTRAINT; Schema: hvn; Owner: postgres
--

ALTER TABLE ONLY hvn.vehicle_configuration
    ADD CONSTRAINT vehicle_configuration_vehicle_code_key UNIQUE (vehicle_code);


--
-- TOC entry 5807 (class 1259 OID 31589)
-- Name: road_access_segment_idx; Type: INDEX; Schema: hvn; Owner: postgres
--

CREATE INDEX road_access_segment_idx ON hvn.road_access USING btree (segment_id);


--
-- TOC entry 5808 (class 1259 OID 31590)
-- Name: road_access_vehicle_idx; Type: INDEX; Schema: hvn; Owner: postgres
--

CREATE INDEX road_access_vehicle_idx ON hvn.road_access USING btree (vehicle_id);


--
-- TOC entry 5802 (class 1259 OID 31556)
-- Name: road_segment_geometry_gix; Type: INDEX; Schema: hvn; Owner: postgres
--

CREATE INDEX road_segment_geometry_gix ON hvn.road_segment USING gist (geometry);


--
-- TOC entry 5811 (class 2606 OID 31579)
-- Name: road_access road_access_segment_fk; Type: FK CONSTRAINT; Schema: hvn; Owner: postgres
--

ALTER TABLE ONLY hvn.road_access
    ADD CONSTRAINT road_access_segment_fk FOREIGN KEY (segment_id) REFERENCES hvn.road_segment(segment_id);


--
-- TOC entry 5812 (class 2606 OID 31601)
-- Name: road_access road_access_source_fk; Type: FK CONSTRAINT; Schema: hvn; Owner: postgres
--

ALTER TABLE ONLY hvn.road_access
    ADD CONSTRAINT road_access_source_fk FOREIGN KEY (source_id) REFERENCES hvn.road_rule_source(source_id);


--
-- TOC entry 5813 (class 2606 OID 31584)
-- Name: road_access road_access_vehicle_fk; Type: FK CONSTRAINT; Schema: hvn; Owner: postgres
--

ALTER TABLE ONLY hvn.road_access
    ADD CONSTRAINT road_access_vehicle_fk FOREIGN KEY (vehicle_id) REFERENCES hvn.vehicle_configuration(vehicle_id);


-- Completed on 2026-07-21 16:11:08

--
-- PostgreSQL database dump complete
--

\unrestrict R67Whw9gsyCA0hBGBRxoGXvd5R0Mtgc8OrmIC0KwBp2aoHdKBlyV4Izi6mP4yrL

