from oaas import clients


def test_make_id():
    for _ in range(100):
        id = clients._make_id()
        assert len(id) <= 128
        assert id.islower()
        assert all(c.isalpha() or c == "-" for c in id)


def test_make_key():
    for _ in range(100):
        key = clients._make_key()
        assert len(key) == 36
        assert all(c.isalnum() or c == "-" for c in key)
