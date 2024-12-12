-- 1
SELECT 
    t.FirstName,
    t.LastName,
    CASE t.Gender
        WHEN 'M' THEN 'Muško'
        WHEN 'F' THEN 'Žensko'
        WHEN 'Unknown' THEN 'Nepoznato'
        WHEN 'Other' THEN 'Ostalo'
    END as Gender,
    c.Name as Country,
    c.AverageSalary
FROM Trainer t
JOIN FitnessCenter fc ON t.FitnessCenterID = fc.FitnessCenterID
JOIN Country c ON fc.CountryID = c.CountryID;

-- 2
SELECT
	a.ActivityID,
    a.ActivityType,
    s.StartTime,
    s.EndTime,
    STRING_AGG(t.LastName || ', ' || LEFT(t.FirstName, 1) || '.', '; ') as MainTrainers
FROM Schedule s
JOIN Activity a ON s.ActivityID = a.ActivityID
JOIN TrainerActivity ta ON a.ActivityID = ta.ActivityID
JOIN Trainer t ON ta.TrainerID = t.TrainerID
WHERE ta.IsMainTrainer = true
GROUP BY a.ActivityID, a.ActivityType, s.StartTime, s.EndTime;

-- 3
SELECT fc.Name, COUNT(*) as ActivityCount
FROM FitnessCenter fc
JOIN Trainer t ON fc.FitnessCenterID = t.FitnessCenterID
JOIN TrainerActivity ta ON t.TrainerID = ta.TrainerID
JOIN Schedule s ON ta.ActivityID = s.ActivityID
GROUP BY fc.FitnessCenterID
ORDER BY ActivityCount DESC
LIMIT 3;

-- 4
SELECT
    t.FirstName,
    t.LastName,
    CASE 
        WHEN COUNT(ta.ActivityID) = 0 THEN 'Dostupan'
        WHEN COUNT(ta.ActivityID) <= 3 THEN 'Aktivan'
        ELSE 'Potpuno zauzet'
    END as Status
FROM Trainer t
LEFT JOIN TrainerActivity ta ON t.TrainerID = ta.TrainerID
GROUP BY t.TrainerID, t.FirstName, t.LastName;

-- 5
SELECT DISTINCT m.FirstName, m.LastName
FROM Member m
JOIN ScheduleMember sm ON m.MemberID = sm.MemberID
JOIN Schedule s ON sm.ScheduleID = s.ScheduleID;

-- 6
SELECT DISTINCT 
    t.FirstName,
    t.LastName
FROM Trainer t
JOIN TrainerActivity ta ON t.TrainerID = ta.TrainerID
JOIN Schedule s ON ta.ActivityID = s.ActivityID
WHERE EXTRACT(YEAR FROM s.StartTime) BETWEEN 2019 AND 2022;

-- 7
SELECT 
    c.Name,
    a.ActivityType,
    ROUND(AVG(
        (SELECT COUNT(*) FROM ScheduleMember sm WHERE sm.ScheduleID = s.ScheduleID)::numeric
    ), 2) AS AvgParticipation
FROM Country c
JOIN FitnessCenter fc ON c.CountryID = fc.CountryID
JOIN Trainer t ON fc.FitnessCenterID = t.FitnessCenterID
JOIN TrainerActivity ta ON t.TrainerID = ta.TrainerID
JOIN Activity a ON ta.ActivityID = a.ActivityID
JOIN Schedule s ON a.ActivityID = s.ActivityID
GROUP BY c.Name, a.ActivityType;

-- 8
SELECT 
    c.Name AS CountryName,
    COUNT(*) as ParticipationCount
FROM Country c
JOIN FitnessCenter fc ON c.CountryID = fc.CountryID
JOIN Trainer t ON fc.FitnessCenterID = t.FitnessCenterID
JOIN TrainerActivity ta ON t.TrainerID = ta.TrainerID
JOIN Activity a ON ta.ActivityID = a.ActivityID
JOIN Schedule s ON a.ActivityID = s.ActivityID
JOIN ScheduleMember sm ON s.ScheduleID = sm.ScheduleID
WHERE a.ActivityType = 'Injury rehabilitation'
GROUP BY c.Name
ORDER BY ParticipationCount DESC
LIMIT 10;

-- 9
SELECT 
    a.ActivityType,
    s.StartTime,
    CASE WHEN COUNT(sm.MemberID) >= a.MaxParticipants THEN 'Popunjeno'
         ELSE 'Ima mjesta'
    END AS Status
FROM Activity a
JOIN Schedule s ON a.ActivityID = s.ActivityID
LEFT JOIN ScheduleMember sm ON s.ScheduleID = sm.ScheduleID
GROUP BY a.ActivityType, s.StartTime, a.MaxParticipants;

-- 10
SELECT 
    t.FirstName,
    t.LastName,
    SUM(
        a.PricePerSession * 
        (SELECT COUNT(*) FROM ScheduleMember sm WHERE sm.ScheduleID = s.ScheduleID)
    ) as TotalIncome
FROM Trainer t
JOIN TrainerActivity ta ON t.TrainerID = ta.TrainerID
JOIN Activity a ON ta.ActivityID = a.ActivityID
JOIN Schedule s ON a.ActivityID = s.ActivityID
WHERE ta.IsMainTrainer = true
GROUP BY t.TrainerID, t.FirstName, t.LastName
ORDER BY TotalIncome DESC
LIMIT 10;