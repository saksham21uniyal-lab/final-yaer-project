# Symtrack App - Backend Chat Improvement Plan

**Approved Plan Steps:**
1. [ ] Update chatbot.py: Replace get_possible_conditions with new get_disease function (simple string matching on SYMPTOM_DISEASE table)
2. [ ] Update init_db.py: Add SYMPTOM_DISEASE table + sample data
3. [ ] Update chat_server.py: Adapt to use get_disease return value (string → list)
4. [ ] Run init_db.py to create/populate new table
5. [ ] Restart chat_server.py and test /chat endpoint
6. [ ] Verify Flutter app chat works without 500 errors

**Status:** Ready for implementation.
