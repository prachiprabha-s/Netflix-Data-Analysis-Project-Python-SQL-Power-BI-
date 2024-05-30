       --CHECKING AND CLEANING--
--------------------------------------

select * from netflix_raw 
where show_id = 's4668'


SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'netflix_raw' AND COLUMN_NAME = 'title';


INSERT INTO netflix_raw (title)
VALUES (N'안녕하세요1');

-- Insert data with Unicode literals
INSERT INTO netflix_raw (title) VALUES (N'안녕하세요');

-- Check column definition
EXEC sp_columns 'netflix_raw';

SELECT show_id, title
FROM netflix_raw
WHERE title LIKE '%???????%';

UPDATE netflix_raw
SET title = N'안녕하세요'
WHERE show_id = 's8795' -- Adjust condition as per your specific case



UPDATE netflix_raw
SET title = 
    CASE show_id
        WHEN 's5023' THEN N'기생충'
        WHEN 's2639' THEN N'올드보이'
        WHEN 's8775' THEN N'명량'
		WHEN 's7102' THEN N'도둑들'
        WHEN 's4915' THEN N'왕의 남자'
        WHEN 's7109' THEN N'극한직업'
		 WHEN 's2640' THEN N'태극기 휘날리며'
        WHEN 's6178' THEN N'국제시장'
        WHEN 's5975' THEN N'반도'
        -- Add more WHEN clauses for other show_ids
        ELSE title -- Keep existing title if show_id doesn't match any WHEN clause
    END
WHERE show_id IN ('s5023', 's2639', 's8775', 's7102','s4915','s7109','s2640','s6178','s5975'); -- Update rows where show_id is in the list


SELECT title, REPLACE(title, '??', '') AS TrimmedTitle
FROM netflix_raw
where show_id = 's4668';

UPDATE netflix_raw
SET title = REPLACE(title, '?', '')
WHERE title LIKE '?%';

--       #handling duplicates
--------------------------------------
--#IMPORTED TABLE NAMED NETFLIX_RAW TO PERFORM ALL THE CLEANING ACTIONS AND MOVE IT INTO THE FINAL ONE

select * from netflix_raw 
where title in
(select title from netflix_raw
group by title,type
having count(*) > 1)
order by title

with cte as (
select * 
,ROW_NUMBER() over(partition by title , type order by show_id) as rn
from netflix_raw
)
delete from cte 
where rn > 1

select * from netflix_raw


--CREATING INDIVIDUAL TABLES AND SPLITING THE VALUES INTO SINGLE ROW FOR MORE CLEAR AND CONSICE ANALYSIS.
-----------------------------------------------------------------------------------------------------------------

select show_id , trim(value) as director --> for director
into netflix_director
from netflix_raw
cross apply string_split(Director,',')

select * from netflix_director
select * from netflix_raw

select show_id , trim(value) as Country --> for director
into netflix_Country
from netflix_raw
cross apply string_split(Country,',')

select * from netflix_Country

select show_id , trim(value) as Listed_in --> for director
into netflix_listed
from netflix_raw
cross apply string_split(listed_in,',')

select * from netflix_listed

select show_id , trim(value) as cast --> for director
into netflix_cast
from netflix_raw
cross apply string_split(cast,',')

select * from netflix_raw

insert into netflix_Country 
select  show_id,m.country 
from netflix_raw nr
inner join
(
select director,country
from  netflix_country nc
inner join netflix_director nd on nc.show_id=nd.show_id
group by director,country
) 
m on nr.director = m.director
where nr.country is null

SELECT * FROM netflix_Country

 --FINALLY TAKING ALL THE DATA TO A NEW TABLE CALLED NETFLIX_FINAL WHICH WILL BE FURTHER USED IN ANALYSIS
 ------------------------------------------------------------------------------------------------------------

 --first step understanding the dataset

SELECT release_year, COUNT(*) AS countmovies
FROM netflix_final
GROUP BY release_year
having COUNT(*) > 100
ORDER BY release_year 

SELECT release_year, type, COUNT(*) AS count
FROM netflix_final
GROUP BY release_year, type
ORDER BY release_year;



SELECT top 10 title, rating, type
FROM netflix_final
WHERE rating IS NOT NULL
ORDER BY rating DESC

SELECT type, duration, COUNT(*) AS count
FROM netflix_final
GROUP BY type, duration
ORDER BY count DESC;

SELECT rating, COUNT(*) AS count --->duplicated check!
FROM netflix_final
GROUP BY rating
ORDER BY count DESC;

SELECT top 20 Listed_in, COUNT(*) AS count
FROM netflix_listed
GROUP BY Listed_in
ORDER BY count DESC;

select * from netflix_final
select * from netflix_director
select * from netflix_cast
select * from netflix_country
select * from netflix_listed


--diving into analysis and insights

 select show_id, type, title,cast(date_added as date) as date_added,release_year,rating,
 case when duration is null then rating else duration end as duration, description
 into netflix_final
 from netflix_raw


SELECT top 20 count(*) AS no_of_shows,nd.director, type --> to know the top directors based on total number of show_ids
FROM netflix_final nf
INNER JOIN netflix_director nd on nd.show_id = nf.show_id
GROUP BY type, director
ORDER BY no_of_shows desc



with cte as ---directors with their total movie and tv show count along with their rank based on highest total count
(
select nd.director as director, 
SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) AS movie_count,
SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_show_count
from netflix_director nd 
left join netflix_final nf on nd.show_id = nf.show_id 
group by  nd.director
HAVING 
    SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) > 0 and 
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) > 0
)
SELECT 
    director,
    movie_count,
    tv_show_count,
    (movie_count + tv_show_count) AS total_count,
    ROW_NUMBER() OVER (ORDER BY (movie_count + tv_show_count) DESC) AS rank
FROM 
    cte
ORDER BY 
    total_count DESC;


select count(type) AS count_of_type, type --total count of both the movies and shows 
from netflix_final
group by type

SELECT 
    nf.rating,
    COUNT(nf.rating) AS count_of_type,
    d.director
FROM netflix_final nf
LEFT JOIN netflix_director d ON nf.show_id = d.show_id
GROUP BY nf.rating, d.director
ORDER BY count_of_type DESC;
 
update netflix_final---- replacing with null 
set rating = null
where rating like '%min'


select top 10 count(nf.rating) count_of_rating, -- movies and shows distributed based on count of ratings
SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) AS movie_count,
SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_show_count, 
rating
from netflix_final nf 
group by 
     rating
order by count_of_rating desc;

SELECT nf.title, COUNT(*) AS release_count,nd.director,rating --which movies got released twice(to check the demand) and associated director and rating
FROM netflix_final nf 
INNER JOIN netflix_director nd on nd.show_id = nf.show_id
GROUP BY nf.title,nd.director,rating
HAVING COUNT(*) > 1


with cte as (SELECT  ---to find the same date added and release year movies, 
    title,
    date_added,
    release_year,row_number() over(partition by release_year order by release_year desc) as rn
FROM netflix_final
WHERE YEAR(date_added) = release_year and release_year in ('2021','2019','2018','2017'))
select * from cte
where rn <=5


select top 20 type,count(type) as shows,nc.cast --popular actor in netflix 
from netflix_final nf
inner join netflix_cast nc on nc.show_id = nf.show_id
group by type,nc.cast 
order by shows desc



WITH cte AS ( --->in which country movies released the most
    SELECT
        nc.country,
        nl.Listed_in as genre,
        COUNT(*) AS no_of_releasedmovies
    FROM netflix_final nf
    INNER JOIN netflix_Country nc ON nc.show_id = nf.show_id
    INNER JOIN netflix_listed nl ON nl.show_id = nf.show_id
    WHERE nc.country <> ''  -- Filter out empty countries
    GROUP BY nc.country, nl.Listed_in
),
rn AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY country ORDER BY no_of_releasedmovies DESC) AS rn
    FROM cte
)
SELECT country, genre, no_of_releasedmovies,rn
FROM rn
WHERE rn <= 5
ORDER BY no_of_releasedmovies DESC;



SELECT top 5 COUNT(nl.SHOW_ID) as show_id,nl.Listed_in,nd.director,nc.country FROM netflix_listed nl --top 5 directors based on genre 
inner join netflix_director nd on nd.show_id = nl.show_id
inner join netflix_Country nc on nc.show_id = nd.show_id
GROUP BY Listed_in,nd.director,nc.country
order by show_id desc


--avg duration
SELECT nl.listed_in,concat(avg(cast(REPLACE(nf.duration,'min','') AS int)), ' min') as avg_duration FROM netflix_final nf
inner join netflix_listed nl on nl.show_id = nf.show_id
where type = 'Movie'
group by nl.listed_in 


select nd.director --find out directors who have done both the comedy and horror movies
, count(distinct case when ng.listed_in='Comedies' then n.show_id end) as no_of_comedy --> both comedy and horror done by director
, count(distinct case when ng.listed_in='Horror Movies' then n.show_id end) as no_of_horror
from netflix_final n
inner join netflix_listed ng on n.show_id=ng.show_id
inner join netflix_director nd on n.show_id=nd.show_id
where type='Movie' and ng.Listed_in in ('Comedies','Horror Movies')
group by nd.director
having COUNT(distinct ng.Listed_in)=2;



select * from netflix_listed where show_id in 
(select show_id from netflix_director where director='Steve Brill')
order by Listed_in




--3 for each year (as per date added to netflix), which director has maximum number of movies released
with cte as (
select nd.director,YEAR(date_added) as date_year,count(n.show_id) as no_of_movies
from netflix_final N
inner join netflix_director nd on n.show_id=nd.show_id
where type='Movie'
group by nd.director,YEAR(date_added)
)
, cte2 as (
select *
, ROW_NUMBER() over(partition by date_year order by no_of_movies desc, director) as rn
from cte
--order by date_year, no_of_movies desc
)
select * from cte2 where rn=1
order by no_of_movies desc


select count(*) as no_of_show,year(date_added)as date_added from  netflix_final --total shows by year
group by year(date_added)
order by date_added desc

--key insights and recommendations

























