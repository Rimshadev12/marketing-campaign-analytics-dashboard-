DROP TABLE IF EXISTS marketing_campaign_raw;

CREATE TABLE marketing_campaign_raw (
    campaign_id INT,
    company VARCHAR(100),
    campaign_type VARCHAR(50),
    target_audience VARCHAR(100),
    duration_days INT,
    channel_used VARCHAR(50),
    conversion_rate NUMERIC(5,2),
    acquisition_cost NUMERIC(12,2),
    roi NUMERIC(10,2),
    location VARCHAR(100),
    language VARCHAR(50),
    clicks INT,
    impressions INT,
    engagement_score NUMERIC(5,2),
    customer_segment VARCHAR(100),
    campaign_date DATE
);

SELECT COUNT(*) FROM marketing_campaign_raw;

SELECT * FROM marketing_campaign_raw LIMIT 10;

-- dim_company
DROP TABLE dim_company;

CREATE TABLE dim_company (
    company_id SERIAL PRIMARY KEY,
    company VARCHAR(100),
    location VARCHAR(100),
    language VARCHAR(50)
);

INSERT INTO dim_company (company, location, language)
SELECT DISTINCT company, location, language
FROM marketing_campaign_raw;

-- dim_channel
CREATE TABLE dim_channel (
    channel_id SERIAL PRIMARY KEY,
    channel_used VARCHAR(50)
);

INSERT INTO dim_channel (channel_used)
SELECT DISTINCT channel_used
FROM marketing_campaign_raw;

-- dim_campaign
CREATE TABLE dim_campaign (
    campaign_id INT PRIMARY KEY,
    campaign_type VARCHAR(50),
    target_audience VARCHAR(100),
    duration_days INT,
    customer_segment VARCHAR(100)
);

INSERT INTO dim_campaign
SELECT DISTINCT
    campaign_id,
    campaign_type,
    target_audience,
    duration_days,
    customer_segment
FROM marketing_campaign_raw;

-- dim_date
CREATE TABLE dim_date (
    date_id DATE PRIMARY KEY,
    year INT,
    month INT,
    quarter INT
);

INSERT INTO dim_date
SELECT DISTINCT
    campaign_date,
    EXTRACT(YEAR FROM campaign_date),
    EXTRACT(MONTH FROM campaign_date),
    EXTRACT(QUARTER FROM campaign_date)
FROM marketing_campaign_raw;

-- fact table
DROP TABLE fact_campaign_performance;

CREATE TABLE fact_campaign_performance (
    campaign_id INT,
    company_id INT,
    channel_id INT,
    date_id DATE,
    clicks INT,
    impressions INT,
    conversion_rate NUMERIC(5,2),
    acquisition_cost NUMERIC(12,2),
    roi NUMERIC(10,2),
    engagement_score NUMERIC(5,2),

    PRIMARY KEY (campaign_id, company_id, channel_id, date_id),

    FOREIGN KEY (campaign_id) REFERENCES dim_campaign(campaign_id),
    FOREIGN KEY (company_id) REFERENCES dim_company(company_id),
    FOREIGN KEY (channel_id) REFERENCES dim_channel(channel_id),
    FOREIGN KEY (date_id) REFERENCES dim_date(date_id)
);

INSERT INTO fact_campaign_performance
SELECT
    r.campaign_id,
    dc.company_id,
    dch.channel_id,
    r.campaign_date,
    r.clicks,
    r.impressions,
    r.conversion_rate,
    r.acquisition_cost,
    r.roi,
    r.engagement_score
FROM marketing_campaign_raw r
JOIN dim_company dc 
    ON r.company = dc.company
    AND r.location = dc.location
    AND r.language = dc.language
JOIN dim_channel dch 
    ON r.channel_used = dch.channel_used;


SELECT COUNT(*) FROM marketing_campaign_raw;
SELECT COUNT(*) FROM fact_campaign_performance;
SELECT COUNT(*) FROM dim_company;  

SELECT COUNT(DISTINCT company) FROM dim_company;

SELECT campaign_id, company_id, channel_id, date_id, COUNT(*)
FROM fact_campaign_performance
GROUP BY campaign_id, company_id, channel_id, date_id
HAVING COUNT(*) > 1;

SELECT COUNT(*) FROM dim_channel;
SELECT COUNT(*) FROM dim_campaign;
SELECT COUNT(*) FROM dim_date;

CREATE INDEX idx_campaign_id ON fact_campaign_performance(campaign_id);
CREATE INDEX idx_company_id ON fact_campaign_performance(company_id);
CREATE INDEX idx_channel_id ON fact_campaign_performance(channel_id);

-- Best ROI channel
SELECT dch.channel_used,
       ROUND(AVG(roi),2) AS avg_roi
FROM fact_campaign_performance f
JOIN dim_channel dch ON f.channel_id = dch.channel_id
GROUP BY dch.channel_used
ORDER BY avg_roi DESC;

-- Top performing comapny
SELECT dc.company,
       ROUND(SUM(roi),2) AS total_roi
FROM fact_campaign_performance f
JOIN dim_company dc ON f.company_id = dc.company_id
GROUP BY dc.company
ORDER BY total_roi DESC;

-- Monthly trend
SELECT year, month, SUM(roi)
FROM fact_campaign_performance f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY year, month;


SELECT company,
       SUM(roi),
       RANK() OVER (ORDER BY SUM(roi) DESC)
FROM fact_campaign_performance f
JOIN dim_company d ON f.company_id=d.company_id
GROUP BY company;
