CREATE TRIGGER _invhisttriggerfifo 
    AFTER INSERT OR UPDATE ON invhist
        FOR EACH ROW EXECUTE PROCEDURE invhisttriggerfifo();