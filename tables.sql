CREATE TABLE Country (
    CountryID SERIAL PRIMARY KEY,
    Name VARCHAR(100) UNIQUE NOT NULL,
    Population INTEGER NOT NULL CHECK (Population > 0),
    AverageSalary DECIMAL(10,2) NOT NULL CHECK (AverageSalary > 0)
);

CREATE TABLE FitnessCenter (
    FitnessCenterID SERIAL PRIMARY KEY,
	CountryID INTEGER NOT NULL REFERENCES Country(CountryID),
    Name VARCHAR(100) NOT NULL,
    OpenTime TIME NOT NULL,
    CloseTime TIME NOT NULL
);

CREATE TABLE Trainer (
    TrainerID SERIAL PRIMARY KEY,
	FitnessCenterID INTEGER NOT NULL REFERENCES FitnessCenter(FitnessCenterID),
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    DateOfBirth DATE NOT NULL,
    Gender VARCHAR(20) NOT NULL CHECK (Gender IN ('M', 'F', 'Other', 'Unknown'))
);

CREATE TABLE Activity (
    ActivityID SERIAL PRIMARY KEY,
    ActivityType VARCHAR(50) NOT NULL CHECK (
        ActivityType IN ('Strength training', 'Cardio', 'Yoga', 'Dance', 'Injury rehabilitation')
    ),
    PricePerSession DECIMAL(10,2) NOT NULL CHECK (PricePerSession >= 0),
    MaxParticipants INTEGER NOT NULL CHECK (MaxParticipants > 0)
);

CREATE TABLE TrainerActivity (
    TrainerID INTEGER REFERENCES Trainer(TrainerID),
    ActivityID INTEGER REFERENCES Activity(ActivityID),
    IsMainTrainer BOOLEAN NOT NULL,
    PRIMARY KEY (TrainerID, ActivityID)
);

CREATE OR REPLACE FUNCTION check_main_trainer_limit()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.IsMainTrainer THEN
        IF (SELECT COUNT(*) FROM TrainerActivity 
            WHERE TrainerID = NEW.TrainerID 
            AND IsMainTrainer = true) >= 2 THEN
            RAISE EXCEPTION 'Trainer cannot be main trainer for more than 2 activities';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_main_trainer_limit
BEFORE INSERT OR UPDATE ON TrainerActivity
FOR EACH ROW
EXECUTE FUNCTION check_main_trainer_limit();

CREATE OR REPLACE FUNCTION check_trainer_fitness_center()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM TrainerActivity ta
        JOIN Trainer t1 ON ta.TrainerID = t1.TrainerID
        JOIN Trainer t2 ON NEW.TrainerID = t2.TrainerID
        WHERE ta.ActivityID = NEW.ActivityID 
        AND t1.FitnessCenterID != t2.FitnessCenterID
    ) THEN
        RAISE EXCEPTION 'Trainers working on the same activity must belong to the same fitness center';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_trainer_fitness_center
BEFORE INSERT OR UPDATE ON TrainerActivity
FOR EACH ROW
EXECUTE FUNCTION check_trainer_fitness_center();

CREATE TABLE Schedule (
    ScheduleID SERIAL PRIMARY KEY,
    ActivityID INTEGER NOT NULL REFERENCES Activity(ActivityID),
    StartTime TIMESTAMP NOT NULL,
    EndTime TIMESTAMP NOT NULL,
    UniqueCode VARCHAR(50) NOT NULL UNIQUE,
    CONSTRAINT valid_time_range CHECK (EndTime > StartTime 
        AND EXTRACT(EPOCH FROM EndTime - StartTime)/3600 < 2)
);

CREATE TABLE Member (
    MemberID SERIAL PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    DateOfBirth DATE NOT NULL
);

CREATE TABLE ScheduleMember (
    MemberID INTEGER REFERENCES Member(MemberID),
    ScheduleID INTEGER REFERENCES Schedule(ScheduleID),
    PRIMARY KEY (MemberID, ScheduleID)
);

CREATE OR REPLACE FUNCTION check_max_participants()
RETURNS TRIGGER AS $$
DECLARE
    current_count INTEGER;
    max_allowed INTEGER;
BEGIN
    SELECT a.MaxParticipants INTO max_allowed
    FROM Schedule s
    JOIN Activity a ON s.ActivityID = a.ActivityID
    WHERE s.ScheduleID = NEW.ScheduleID;

    SELECT COUNT(*) INTO current_count
    FROM ScheduleMember
    WHERE ScheduleID = NEW.ScheduleID;

    IF current_count >= max_allowed THEN
        RAISE EXCEPTION 'Cannot add member: Maximum number of participants (%) reached for this activity', max_allowed;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_max_participants
BEFORE INSERT ON ScheduleMember
FOR EACH ROW
EXECUTE FUNCTION check_max_participants();